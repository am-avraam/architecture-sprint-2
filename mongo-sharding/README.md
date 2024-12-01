
# Проект с шардированием MongoDB и FastAPI

## Как запустить

### 1. Короткий метод инициализации и проверки (скрипт)
```shell
./scripts/initialize_and_check.sh
```

### 2. Длинный метод. 

### Запуск MongoDB и приложения

Для начала запустите MongoDB и FastAPI приложение с помощью Docker Compose:

```shell
docker compose up -d
```

### Инициализация конфигурационного сервера

После запуска контейнеров подключитесь к серверу конфигурации и инициализируйте его:

```shell
docker exec -it configSrv mongosh --port 27017
```

Выполните команду инициализации:

```javascript
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
});
```

Затем выйдите из консоли:

```shell
exit
```

### Инициализация шардов

#### Инициализация первого шарда

Подключитесь к первому шарду и выполните инициализацию:

```shell
docker exec -it shard1 mongosh --port 27018
```

Выполните команду:

```javascript
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1:27018" }
  ]
});
```

Затем выйдите из консоли:

```shell
exit
```

#### Инициализация второго шарда

Подключитесь ко второму шарду и выполните инициализацию:

```shell
docker exec -it shard2 mongosh --port 27019
```

Выполните команду:

```javascript
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 1, host: "shard2:27019" }
  ]
});
```

Затем выйдите из консоли:

```shell
exit
```

### Инициализация роутера и добавление тестовых данных

Подключитесь к роутеру MongoDB и настройте шардирование:

```shell
docker exec -it mongos_router mongosh --port 27020
```

Выполните следующие команды:

```javascript
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb;

for (var i = 0; i < 1000; i++) db.helloDoc.insert({ age: i, name: "ly" + i });

db.helloDoc.countDocuments();
```

Ожидаемый результат — 1000 документов.

### Проверка шардирования

#### Проверка первого шарда

Подключитесь к первому шарду и проверьте количество документов:

```shell
docker exec -it shard1 mongosh --port 27018
use somedb;
db.helloDoc.countDocuments();
exit
```

Ожидаемый результат — 492 документа.

#### Проверка второго шарда

Подключитесь ко второму шарду и проверьте количество документов:

```shell
docker exec -it shard2 mongosh --port 27019
use somedb;
db.helloDoc.countDocuments();
exit
```

Ожидаемый результат — 508 документов.