#!/bin/bash

# --- КОНФИГУРАЦИЯ ---
# Имя вашего бакета Cloudflare R2
R2_BUCKET="automated-backups" 
# Имя профиля AWS CLI, настроенного для R2 (в файле ~/.aws/config)
AWS_PROFILE="r2-profile" 
# Параметры подключения к MongoDB (контейнер в Docker-сети)
MONGO_HOST="localhost" 
MONGO_PORT="27017"

# Временные пути и имена файлов
BACKUP_DIR="/tmp/mongo_backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TARBALL_NAME="all_dbs_${TIMESTAMP}.tar.gz"
TOOLS_DEB_FILE="mongodb-database-tools-ubuntu2404-x86_64-100.13.0.deb"
TOOLS_DOWNLOAD_URL="https://fastdl.mongodb.org/tools/db/$TOOLS_DEB_FILE"


# --- 1. ПРОВЕРКА И УСТАНОВКА MONGODUMP ---

if ! command -v mongodump &> /dev/null; then
    echo "mongodump не найден. Запуск установки Database Tools..."

    # Скачивание DEB-пакета
    if ! wget -q "$TOOLS_DOWNLOAD_URL"; then
        echo "ОШИБКА: Не удалось скачать Database Tools." >&2
        exit 1
    fi

    # Установка пакета
    sudo dpkg -i "$TOOLS_DEB_FILE"

    # Устранение возможных зависимостей
    sudo apt install -f -y

    # Удаление временного deb-файла
    rm -f "$TOOLS_DEB_FILE"

    # Критическая проверка: Убеждаемся, что установка прошла успешно
    if ! command -v mongodump &> /dev/null; then
        echo "КРИТИЧЕСКАЯ ОШИБКА: Установка mongodump провалилась. Прерывание бэкапа." >&2
        exit 1 
    fi
    echo "✅ mongodump успешно установлен."
fi


# --- 2. ДАМП БАЗЫ ДАННЫХ ---

# Создание временной директории
mkdir -p "$BACKUP_DIR"

echo "Начинаем дамп ВСЕХ баз данных с $MONGO_HOST:$MONGO_PORT"

# mongodump без опции --db дампит все пользовательские БД в $BACKUP_DIR
mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" --out "$BACKUP_DIR" 

# Проверка успешности дампа
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось выполнить mongodump. Проверьте подключение к контейнеру mongo." >&2
  rm -rf "$BACKUP_DIR" 
  exit 1
fi

# --- 3. АРХИВАЦИЯ ---

echo "Архивируем данные в $TARBALL_NAME"
# Архивируем ВСЕ содержимое временной директории, используя относительный путь (.)
tar -czf "$BACKUP_DIR/$TARBALL_NAME" -C "$BACKUP_DIR" .

# --- 4. ЗАГРУЗКА В R2 ---

echo "Загружаем $TARBALL_NAME на Cloudflare R2 в бакет $R2_BUCKET..."
aws s3 cp "$BACKUP_DIR/$TARBALL_NAME" s3://"$R2_BUCKET"/backups/"$TARBALL_NAME" --profile "$AWS_PROFILE"

# Проверка успешности загрузки
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось загрузить файл на R2. Проверьте настройки AWS CLI ($AWS_PROFILE)." >&2
  # Не удаляем файлы, чтобы можно было проверить ошибку
  exit 1
fi

echo "✅ Бэкап успешно завершен и загружен: s3://$R2_BUCKET/backups/$TARBALL_NAME"

# --- 5. ОЧИСТКА ---

echo "Очистка временных файлов..."
rm -rf "$BACKUP_DIR"
echo "Скрипт завершен."
