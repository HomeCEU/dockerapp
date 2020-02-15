Dockerized LAMP env

# Setup instructions
## Using Docker
```bash
git clone git@github.com:HomeCEU/dockerapp.git
cd dockerapp
./app.sh config set GIT_REPO git@github.com:HomeCEU/dts.git # use your app repo obviously
./app.sh config set APP_CONTAINER app # app container name....
./app.sh init # copies .example files, composer install, etc.
cd .docker
docker-compose build
docker-compose up
```
http://localhost:8080

if you wish you can customize the exposed port with

```bash
./app.sh config set APP_PORT 8080
```

or just edit config yourself.

## command exec
You can execute commands in the container from the outside

```bash
./app.sh exec composer update
```

also vendor/bin is in `$PATH` so you can

```bash
# run phpunit
./app.sh exec phpunit

# create a migration
./app.sh exec phinx create MyMigration
````