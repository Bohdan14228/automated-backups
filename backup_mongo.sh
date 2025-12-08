#!/bin/bash


mongodump --version
if [ $? -ne 0 ]; then
  wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2404-x86_64-100.13.0.deb
  sudo dpkg -i mongodb-database-tools-ubuntu2404-x86_64-100.13.0.deb
  sudo apt install -f
fi

# --- Конфигурация ---
# R2_BUCKET остается прежним, DB_NAME больше не нужен
R2_BUCKET="automated-backups" 
BACKUP_DIR="/tmp/mongo_backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
# Изменили имя архива, чтобы отразить, что там все базы данных
TARBALL_NAME="all_dbs_${TIMESTAMP}.tar.gz" 

# Создание временной директории
mkdir -p $BACKUP_DIR
echo "Создана временная директория: $BACKUP_DIR"

# 1. Дамп ВСЕХ пользовательских баз данных (опция --db опущена)
echo "Начинаем дамп ВСЕХ баз данных на mongodb:27017"
# Используем 'mongodb' как хост, так как это имя сервиса в Docker-сети
mongodump --host localhost --port 27017 --out $BACKUP_DIR 

# Проверка успешности дампа
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось выполнить mongodump."
  rm -rf $BACKUP_DIR
  exit 1
fi

# 2. Архивирование (tarball)
echo "Архивируем данные в $TARBALL_NAME"
# Здесь мы архивируем ВСЕ содержимое $BACKUP_DIR
# -C $BACKUP_DIR . означает "перейти в $BACKUP_DIR и заархивировать все, что там есть (.), включая папки баз данных"
tar -czf $BACKUP_DIR/$TARBALL_NAME -C $BACKUP_DIR .

# 3. Загрузка на Cloudflare R2 через AWS CLI
echo "Загружаем $TARBALL_NAME на R2..."
aws s3 cp $BACKUP_DIR/$TARBALL_NAME s3://$R2_BUCKET/backups/$TARBALL_NAME --profile r2-profile

# Проверка успешности загрузки
if [ $? -ne 0 ]; then
  echo "ОШИБКА: Не удалось загрузить файл на R2."
  exit 1
fi

echo "✅ Бэкап всех баз данных успешно загружен: s3://$R2_BUCKET/backups/$TARBALL_NAME"

# 4. Очистка временных файлов
echo "Очистка временных файлов..."
rm -rf $BACKUP_DIR
echo "Готово."