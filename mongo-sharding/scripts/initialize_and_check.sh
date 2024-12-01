#!/bin/bash

# Цвета для подсветки
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # Нет цвета

# Запуск Docker Compose
echo "Запуск MongoDB и приложения..."
docker compose up -d

# Ожидание старта всех контейнеров
echo "Ожидание запуска контейнеров..."
sleep 15  # Увеличим время ожидания, чтобы контейнеры успели подняться

# Инициализация конфигурационного сервера
echo "Инициализация конфигурационного сервера..."
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
});
EOF

sleep 5  # Пауза для завершения инициализации конфигурационного сервера

# Инициализация первого шарда
echo "Инициализация первого шарда..."
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
});
EOF

sleep 5  # Пауза для завершения инициализации первого шарда

# Инициализация второго шарда
echo "Инициализация второго шарда..."
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 1, host: "shard2:27019" }
  ]
});
EOF

sleep 5  # Пауза для завершения инициализации второго шарда

# Ожидание запуска роутера
echo "Проверка статуса роутера..."
while ! docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
db.runCommand({ ping: 1 })
EOF
do
    echo "Роутер ещё не готов. Ожидание..."
    sleep 5
done

# Инициализация роутера и добавление шардов
echo "Инициализация роутера и настройка шардирования..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb;

for (var i = 0; i < 1000; i++) db.helloDoc.insert({ age: i, name: "ly" + i });
EOF

# Проверка количества документов на первом шарде
echo "Проверка количества документов на первом шарде..."
count_shard1=$(docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF
)

echo -e "${YELLOW}Количество документов на первом шарде: ${GREEN}$count_shard1${NC}"

# Проверка количества документов на втором шарде
echo "Проверка количества документов на втором шарде..."
count_shard2=$(docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF
)

echo -e "${YELLOW}Количество документов на втором шарде: ${GREEN}$count_shard2${NC}"

echo -e "${GREEN}Инициализация завершена и проверка выполнена.${NC}"
