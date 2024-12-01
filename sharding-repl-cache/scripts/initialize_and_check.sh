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
sleep 15

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

# Инициализация первого репликасета rs0
echo "Инициализация первого репликасета rs0..."
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "shard1:27018" },
    { _id: 1, host: "shard2:27019" },
    { _id: 2, host: "shard3:27021" }
  ]
});
EOF

sleep 5  # Пауза для завершения инициализации rs0

# Инициализация второго репликасета rs1
echo "Инициализация второго репликасета rs1..."
docker compose exec -T shard4 mongosh --port 27022 --quiet <<EOF
rs.initiate({
  _id: "rs1",
  members: [
    { _id: 0, host: "shard4:27022" },
    { _id: 1, host: "shard5:27023" },
    { _id: 2, host: "shard6:27024" }
  ]
});
EOF

sleep 5  # Пауза для завершения инициализации rs1

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
sh.addShard("rs0/shard1:27018,shard2:27019,shard3:27021");
sh.addShard("rs1/shard4:27022,shard5:27023,shard6:27024");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb;

for (var i = 0; i < 1000; i++) db.helloDoc.insert({ age: i, name: "ly" + i });
EOF

echo -e "${GREEN}Инициализация завершена.${NC}"
