#!/bin/bash

# 1. Скачивание (вы уже сделали выше)
wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2404-x86_64-100.13.0.deb

# 2. Установка пакета
sudo dpkg -i mongodb-database-tools-ubuntu2404-x86_64-100.13.0.deb

# 3. Устранение возможных зависимостей
sudo apt install -f