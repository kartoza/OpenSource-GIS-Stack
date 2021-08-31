SHELL := /bin/bash


help:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Please visit https://kartoza.github.io/osgs/introduction.html"
	@echo "for detailed help."
	@echo "------------------------------------------------------------------"


# We need to declare phony here since the docs dir exists
# otherwise make tries to execute the docs file directly
.PHONY: docs
docs:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Making sphinx docs"
	@echo "------------------------------------------------------------------"
	$(MAKE) -C sphinx html
	@cp -r  sphinx/build/html/* docs
	$(MAKE) -C sphinx latexpdf
	@cp sphinx/build/latex/osgs.pdf osgs-manual.pdf

ps:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Current status"
	@echo "------------------------------------------------------------------"
	@docker-compose ps

configure: disable-all-services prepare-templates site-config enable-hugo configure-scp configure-htpasswd deploy

deploy:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Starting basic nginx site"
	@echo "------------------------------------------------------------------"
	@docker-compose up -d
	@docker-compose logs -f

configure-htpasswd:
	@echo "------------------------------------------------------------------"
	@echo "Configuring password controlled file sharing are for your site"
	@echo "Accessible at /files/"
	@echo "Access credentials will be stored in .env"
	@echo "------------------------------------------------------------------"
	# bcrypt encrypted pwd, be sure to usie nginx:alpine nginx image
	@export PASSWD=$$(pwgen 20 1); \
	       	htpasswd -cbB conf/nginx_conf/htpasswd web $$PASSWD; \
		echo "#User account for protected areas of the site using httpauth" >> .env; \
		echo "#You can add more accounts to conf/nginx_conf/htpasswd using the htpasswd tool" >> .env; \
		echo $$PASSWD >> .env; \
		echo "Files sharing htpasswd set to $$PASSWD"
	@make enable-files

disable-all-services:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Disabling services"
	@echo "This will remove any symlinks in conf/nginx_conf/locations and conf/nginx_conf/upstreams"
	@echo "effectively disabling all services exposed by nginx"
	@echo "------------------------------------------------------------------"
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@find ./conf/nginx_conf/locations -maxdepth 1 -type l -delete
	@find ./conf/nginx_conf/upstreams -maxdepth 1 -type l -delete
	@echo "" > enabled-profiles


prepare-templates: 
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Preparing templates"
	@echo "This will replace any local configuration changes you have made"
	@echo "in .env, conf/nginx_conf/servername.conf"
	@echo "------------------------------------------------------------------"
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@cp .env.example .env
	@cp conf/nginx_conf/servername.conf.example conf/nginx_conf/servername.conf
	@echo "Please enter your valid domain name for the site."
	@echo "e.g. example.org or subdomain.example.org:"
	@read -p "Domain name: " DOMAIN; \
		rpl example.org $$DOMAIN conf/nginx_conf/servername.conf .env; 
	@echo "We are going to set up a self signed certificate now."
	@make configure-ssl-self-signed
	@cp conf/nginx_conf/ssl/certificates.conf.selfsigned.example conf/nginx_conf/ssl/ssl.conf
	@echo "Afterwards if you want to put the server into production mode"
	@echo "please run:"
	@echo "make configure-letsencrypt-ssl"

configure-ssl-self-signed:
	@mkdir -p ./certbot/certbot/conf/
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./certbot/certbot/conf/nginx-selfsigned.key -out ./certbot/certbot/conf/nginx-selfsigned.crt
	#@rpl "BEGIN CERTIFICATE" "BEGIN TRUSTED CERTIFICATE" ./certbot/certbot/conf/nginx-selfsigned.crt
	#@rpl "END CERTIFICATE" "END  TRUSTED CERTIFICATE" ./certbot/certbot/conf/nginx-selfsigned.crt
	#@rpl "BEGIN PRIVATE KEY" "TRUSTED CERTIFICATE" ./certbot/certbot/conf/nginx-selfsigned.key
	#@rpl "END PRIVATE KEY" "TRUSTED CERTIFICATE" ./certbot/certbot/conf/nginx-selfsigned.key

configure-letsencrypt-ssl:
	@echo "Do you want to set up SSL using letsencrypt?"
	@echo "This is recommended for production!"
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo "Please enter your valid domain name for the SSL certificate."
	@echo "e.g. example.org or subdomain.example.org:"
	@read -p "Domain name: " DOMAIN; \
		rpl example.org $$DOMAIN nginx_certbot_init_conf/nginx.conf init-letsencrypt.sh; 
	@cp nginx_certbot_init_conf/nginx.conf.example nginx_certbot_init_conf/nginx.conf
	@cp init-letsencrypt.sh.example init-letsencrypt.sh
	@cp conf/nginx_conf/ssl/ssl.conf.example conf/nginx_conf/ssl/ssl.conf
	@read -p "Valid Contact Person Email Address: " EMAIL; \
	   rpl validemail@yourdomain.org $$EMAIL init-letsencrypt.sh .env

site-config:
	@echo "------------------------------------------------------------------"
	@echo "Configure your static site content management system"
	@echo "You should only do this once per site deployment"
	@echo "------------------------------------------------------------------"
	@echo "This will replace any local configuration changes you have made"
	@echo "------------------------------------------------------------------"
	@echo -n "Are you sure you want to continue? [y/N] " && read ans && [ $${ans:-N} = y ]
	@cp ./conf/hugo_conf/config.yaml.example ./conf/hugo_conf/config.yaml
	@echo "Please enter the site domain name (default 'example.com')"
	@read -p "Domain name: " result; \
	  DOMAINNAME=$${result:-"example.com"} && \
	  rpl -q {{siteDomain}} "$$DOMAINNAME" $(shell pwd)/conf/hugo_conf/config.yaml
	@echo "Please enter the title of your website (default 'Geoservices')"
	@read -p "Site Title: " result; \
	  SITETITLE=$${result:-"Geoservices"} && \
	  rpl -q {{siteTitle}} "$$SITETITLE" $(shell pwd)/conf/hugo_conf/config.yaml
	@echo "Please enter the name of the website owner (default 'Kartoza')"
	@read -p "Site Owner: " result; \
	  SITEOWNER=$${result:-"Kartoza"} && \
	  rpl -q {{ownerName}} "$$SITEOWNER" $(shell pwd)/conf/hugo_conf/config.yaml
	@echo "Please supply the URL of the site owner (default 'www.kartoza.com')."
	@read -p "Owner URL: " result; \
	  OWNERURL=$${result:-"www.kartoza.com"} && \
	  rpl -q {{ownerDomain}} "$$OWNERURL" $(shell pwd)/conf/hugo_conf/config.yaml
	@echo "Please supply a valid public URL to the Website Logo."
	@echo "Be sure to include the protocol prefix (e.g. https://)"
	@read -p "Logo URL: " result; \
	  LOGOURL=$${result:-"img/Circle-icons-stack.svg"} && \
	  rpl -q {{logoURL}} "$$LOGOURL" $(shell pwd)/conf/hugo_conf/config.yaml

#----------------- Hugo --------------------------

enable-hugo:
	-@cd conf/nginx_conf/locations; ln -s hugo.conf.available hugo.conf
	@echo "hugo" >> enabled-profiles

start-hugo:
	@docker-compose up -d

disable-hugo:
	@cd conf/nginx_conf/locations; rm hugo.conf
	# Remove from enabled-profiles
	@sed -i '/hugo/d' enabled-profiles

hugo-logs:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Polling hugo logs"
	@echo "------------------------------------------------------------------"
	@docker-compose logs -f hugo

backup-hugo:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Creating a backup of hugo"
	@echo "------------------------------------------------------------------"
	-@mkdir -p backups
	@docker-compose run --rm -v ${PWD}/backups:/backups nginx tar cvfz /backups/hugo-backup.tar.gz /hugo
	@cp ./backups/hugo-backup.tar.gz ./backups/

restore-hugo:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Restore last backup of hugo from /backups/hugo-backup.tar.gz"
	@echo "If you wist to restore an older backup, first copy it to /backups/hugo-backup.tar.gz"
	@echo "Note: Restoring will OVERWRITE all data currently in your hugo content dir."
	@echo "------------------------------------------------------------------"
	@echo -n "Are you sure you want to continue? [y/N] " && read ans && [ $${ans:-N} = y ]
	-@mkdir -p backups
	@docker-compose run --rm -v ${PWD}/backups:/backups nginx sh -c "cd /hugo && tar xvfz /backups/hugo-backup.tar.gz --strip 1"

#----------------- Docs --------------------------

enable-docs:
	-@cd conf/nginx_conf/locations; ln -s docs.conf.available docs.conf

disable-docs:
	@cd conf/nginx_conf/locations; rm docs.conf

enable-files:
	-@cd conf/nginx_conf/locations; ln -s files.conf.available files.conf

disable-files:
	@cd conf/nginx_conf/locations; rm files.conf

#----------------- GeoServer --------------------------

deploy-geoserver: enable-geoserver configure-geoserver-passwd start-geoserver

start-geoserver:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Starting GeoServer"
	@echo "------------------------------------------------------------------"
	@docker-compose --profile=geoserver up -d
	@docker-compose restart nginx

configure-geoserver-passwd:
	@export PASSWD=$$(pwgen 20 1); \
		rpl GEOSERVER_ADMIN_PASSWORD=myawesomegeoserver GEOSERVER_ADMIN_PASSWORD=$$PASSWD .env; \
		echo "GeoServer password set to $$PASSWD"

enable-geoserver:
	-@cd conf/nginx_conf/locations; ln -s geoserver.conf.available geoserver.conf
	@echo "geoserver" >> enabled-profiles
	@make setup-compose-profile

disable-geoserver:
	@cd conf/nginx_conf/locations; rm geoserver.conf
	# Remove from enabled-profiles
	@sed -i '/geoserver/d' enabled-profiles
	@make setup-compose-profile

geoserver-logs:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Polling Geoserver logs"
	@echo "------------------------------------------------------------------"
	@docker-compose logs -f geoserver

#----------------- QGIS Server --------------------------

deploy-qgis-server: enable-qgis-server start-qgis-server

start-qgis-server:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Starting QGIS Server"
	@echo "------------------------------------------------------------------"
	@docker-compose --profile=qgis-server up -d --scale qgis-server=10 --remove-orphans
	@docker-compose restart nginx

enable-qgis-server:
	-@cd conf/nginx_conf/locations; ln -s qgis-server.conf.available qgis-server.conf
	-@cd conf/nginx_conf/upstreams; ln -s qgis-server.conf.available qgis-server.conf
	@echo "qgis-server" >> enabled-profiles
	@make setup-compose-profile

disable-qgis-server:
	@docker-compose kill qgis-server
	@docker-compose rm qgis-server
	@cd conf/nginx_conf/locations; rm qgis-server.conf
	@cd conf/nginx_conf/upstreams; rm qgis-server.conf
	# Remove from enabled-profiles
	@sed -i '/qgis/d' enabled-profiles
	@make setup-compose-profile

reinitialise-qgis-server: rm-qgis-server start-qgis-server
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Restarting QGIS Server and Nginx"
	@echo "------------------------------------------------------------------"
	@docker-compose restart nginx
	@docker-compose logs -f qgis-server 

rm-qgis-server:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Stopping QGIS Server and Nginx"
	@echo "------------------------------------------------------------------"
	@docker-compose kill qgis-server
	@docker-compose rm qgis-server

qgis-logs:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Polling QGIS Server logs"
	@echo "------------------------------------------------------------------"
	@docker-compose logs -f qgis-server

#----------------- Mapproxy --------------------------

deploy-mapproxy: enable-mapproxy configure-mapproxy start-mapproxy

start-mapproxy:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Starting Mapproxy"
	@echo "------------------------------------------------------------------"
	@docker-compose --profile=mapproxy up -d 
	@docker-compose restart nginx

reinitialise-mapproxy:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Restarting Mapproxy and clearing its cache"
	@echo "------------------------------------------------------------------"
	@docker-compose kill mapproxy
	@docker-compose rm mapproxy
	@rm -rf conf/mapproxy_conf/cache_data/*
	@docker-compose up -d mapproxy
	@docker-compose logs -f mapproxy

configure-mapproxy:
	@echo "=========================:"
	@echo "Mapproxy configurations:"
	@echo "=========================:"
	@cp conf/mapproxy_conf/mapproxy.yaml.example conf/mapproxy_conf/mapproxy.yaml 
	@cp conf/mapproxy_conf/seed.yaml.example conf/mapproxy_conf/seed.yaml 
	@echo "We have created template mapproxy.yaml and seed.yaml"
	@echo "configuration files in conf/mapproxy_conf."
	@echo "You will need to hand edit those files and then "
	@echo "restart mapproxy for those edits to take effect."
	@echo "see: make reinitialise-mapproxy"	

enable-mapproxy:
	-@cd conf/nginx_conf/locations; ln -s mapproxy.conf.available mapproxy.conf
	@echo "mapproxy" >> enabled-profiles
	@make setup-compose-profile

disable-mapproxy:
	@cd conf/nginx_conf/locations; rm mapproxy.conf
	# Remove from enabled-profiles
	@sed -i '/mapproxy/d' enabled-profiles
	@make setup-compose-profile

#----------------- Postgres --------------------------

deploy-postgres: enable-postgres configure-postgres start-postgres

start-postgres:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Starting Postgres"
	@echo "------------------------------------------------------------------"
	@docker-compose --profile=db up -d 

reinitialise-postgres:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Restarting postgres"
	@echo "------------------------------------------------------------------"
	@docker-compose kill db
	@docker-compose rm db
	@docker-compose up -d db
	@docker-compose logs -f db

configure-postgres: configure-timezone 
	@echo "=========================:"
	@echo "Postgres configuration:"
	@echo "=========================:"
	@export PASSWD=$$(pwgen 20 1); \
		rpl POSTGRES_PASSWORD=docker POSTGRES_PASSWORD=$$PASSWD .env; \
		echo "Postgres password set to $$PASSWD"

enable-postgres:
	@echo "db" >> enabled-profiles
	@make setup-compose-profile

disable-postgres:
	@echo "This is currently a stub"	
	# Remove from enabled-profiles
	@sed -i '/db/d' enabled-profiles
	@make setup-compose-profile

configure-timezone:
	@echo "Please enter the timezone for your server"
	@echo "See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
	@echo "Follow exactly the format of the TZ Database Name column"
	@read -p "Server Time Zone (e.g. Etc/UTC):" TZ; \
	   rpl TIMEZONE=Etc/UTC TIMEZONE=$$TZ .env

db-shell:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Creating db shell"
	@echo "------------------------------------------------------------------"
	@docker-compose exec -u postgres db psql gis

db-qgis-project-backup:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Backing up QGIS project stored in db"
	@echo "------------------------------------------------------------------"
	@docker-compose exec -u postgres db pg_dump -f /tmp/QGISProject.sql -t qgis_projects gis
	@docker cp osgisstack_db_1:/tmp/QGISProject.sql .
	@docker-compose exec -u postgres db rm /tmp/QGISProject.sql
	@ls -lah QGISProject.sql

db-qgis-project-restore:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Restoring QGIS project to db"
	@echo "------------------------------------------------------------------"
	@docker cp QGISProject.sql osgisstack_db_1:/tmp/ 
	# - at start of next line means error will be ignored (in case QGIS project table isnt already there)
	-@docker-compose exec -u postgres db psql -c "drop table qgis_projects;" gis 
	@docker-compose exec -u postgres db psql -f /tmp/QGISProject.sql -d gis
	@docker-compose exec db rm /tmp/QGISProject.sql
	@docker-compose exec -u postgres db psql -c "select name from qgis_projects;" gis 

db-backup:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Backing up entire GIS postgres db"
	@echo "------------------------------------------------------------------"
	@docker-compose exec -u postgres db pg_dump -Fc -f /tmp/osgisstack-database.dmp gis
	@docker cp osgisstack_db_1:/tmp/osgisstack-database.dmp .
	@docker-compose exec -u postgres db rm /tmp/osgisstack-database.dmp
	@ls -lah osgisstack-database.dmp

db-backupall:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Backing up all postgres databases"
	@echo "------------------------------------------------------------------"
	@docker-compose exec -u postgres db pg_dumpall -f /tmp/osgisstack-all-databases.dmp
	@docker cp osgisstack_db_1:/tmp/osgisstack-all-databases.dmp .
	@docker-compose exec -u postgres db rm /tmp/osgisstack-all-databases.dmp
	@ls -lah osgisstack-all-databases.dmp

db-backup-mergin-base-schema:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Backing up mergin base schema from  postgres db"
	@echo "------------------------------------------------------------------"
	@docker-compose exec -u postgres db pg_dump -Fc -f /tmp/mergin-base-schema.dmp -n mergin_sync_base_do_not_touch gis
	@docker cp osgisstack_db_1:/tmp/mergin-base-schema.dmp .
	@docker-compose exec -u postgres db rm /tmp/mergin-base-schema.dmp
	@ls -lah mergin-base-schema.dmp

#----------------- SCP --------------------------

configure-scp: start-scp
	@echo "------------------------------------------------------------------"
	@echo "Copying .ssh/authorized keys to all scp shares."
	@echo "------------------------------------------------------------------"
	@cat ~/.ssh/authorized_keys > conf/scp_conf/geoserver_data
	@cat ~/.ssh/authorized_keys > conf/scp_conf/qgis_projects
	@cat ~/.ssh/authorized_keys > conf/scp_conf/qgis_fonts
	@cat ~/.ssh/authorized_keys > conf/scp_conf/qgis_svg
	@cat ~/.ssh/authorized_keys > conf/scp_conf/hugo_data
	@cat ~/.ssh/authorized_keys > conf/scp_conf/odm_data
	@cat ~/.ssh/authorized_keys > conf/scp_conf/general_data

start-scp:
	@docker-compose up -d scp	

enable-scp:
	@echo "scp" >> enabled-profiles
	@make setup-compose-profile

disable-scp:
	# Remove from enabled-profiles
	@sed -i '/db/d' enabled-profiles
	@make setup-compose-profile	

#----------------- OSM Mirror --------------------------

deploy-osm-mirror: enable-osm-mirror configure-osm-mirror start-osm-mirror

configure-osm-mirror: 
	@echo "=========================:"
	@echo "OSM Mirror specific updates:"
	@echo "=========================:"
	@echo "I have prepared my clip area (optional) and"
	@echo "saved it as conf/osm_conf/clip.geojson."
	@echo "You can easily create such a clip document"
	@echo "at https://geojson.io or by using QGIS"
	@read -p "Press enter to continue" CONFIRM;
	@make get-pbf

get-pbf:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Fetching pbf if not cached and then copying to settings dir"
	@echo "You can download PBF files from GeoFabrik here:"
	@echo "https://download.geofabrik.de/"
	@echo "e.g. https://download.geofabrik.de/europe/portugal-latest.osm.pbf"
	@echo "------------------------------------------------------------------"
	@read -p "URL For Country PBF File: " URL; \
	   wget -c -N -O conf/osm_conf/country.pbf $$URL;

start-osm-mirror:
	@docker-compose --profile=osm up -d 

enable-osm-mirror:
	@echo "osm" >> enabled-profiles
	@make setup-compose-profile

disable-osm-mirror:
	# Remove from enabled-profiles
	@sed -i '/osm/d' enabled-profiles
	@make setup-compose-profile	

#----------------- Postgrest --------------------------

configure-postgrest: start-postgrest
	@echo "=========================:"
	@echo "PostgREST specific updates:"
	@echo "=========================:"
	@export PASSWD=$$(pwgen 20 1); \
		rpl PGRST_JWT_SECRET=foobarxxxyyyzzz PGRST_JWT_SECRET=$$PASSWD .env; \
		echo "PostGREST JWT token set to $$PASSWD"

start-postgrest:
	@docker-compose up -d postgrest

enable-postgrest:
	@echo "postgrest" >> enabled-profiles

disable-postgrest:
	# Remove from enabled-profiles
	@sed -i '/postgrest/d' enabled-profiles

configure-mergin-client:
	@echo "=========================:"
	@echo "Mergin related configs:"
	@echo "=========================:"
	@read -p "Mergin User (not email address): " USER; \
	   rpl mergin_username $$USER .env
	@read -p "Mergin Password: " PASSWORD; \
	   rpl mergin_password $$PASSWORD .env
	@read -p "Mergin Project (without username part): " PROJECT; \
	   rpl mergin_project $$PROJECT .env
	@read -p "Mergin Project GeoPackage: " PACKAGE; \
	   rpl mergin_project_geopackage.gpkg $$PACKAGE .env
	@read -p "Mergin Database Schema to hold mirror of geopackage): " SCHEMA; \
	   rpl schematoreceivemergindata $$SCHEMA .env

#----------------- LizMap --------------------------

# LIZMAP IS NOT WORKING YET.....


deploy-lizmap: configure-lizmap enable-lizmap start-lizmap

start-lizmap:
	@docker-compose up -d lizmap

configure-lizmap:
	@echo "=========================:"
	@echo "Configuring lizmap:"
	@echo "=========================:"
	@docker-compose --profile=lizmap up -d 
	@docker-compose restart nginx

enable-lizmap:
	-@cd conf/nginx_conf/locations; ln -s lizmap.conf.available lizmap.conf
	@echo "lizmap" >> enabled-profiles


disable-lizmap:
	@cd conf/nginx_conf/locations; rm lizmap.conf
	# Remove from enabled-profiles
	@sed -i '/lizmap/d' enabled-profiles

#######################################################
#   General Utilities
#######################################################

site-reset:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Reset site configuration to default values"
	@echo "This will replace any local configuration changes you have made"
	@echo "------------------------------------------------------------------"
	@echo -n "Are you sure you want to continue? [y/N] " && read ans && [ $${ans:-N} = y ]
	@cp ./conf/hugo_conf/config.yaml.example ./conf/hugo_conf/config.yaml

init-letsencrypt:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Getting an SSL cert from letsencypt"
	@echo "------------------------------------------------------------------"
	@./init-letsencrypt.sh	
	@docker-compose --profile=certbot-init kill
	@docker-compose --profile=certbot-init rm
	@make build-pbf

restart:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Restarting all containers"
	@echo "------------------------------------------------------------------"
	@docker-compose restart
	@docker-compose logs -f

logs:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Tailing logs"
	@echo "------------------------------------------------------------------"
	@docker-compose logs -f

nginx-shell:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Creating nginx shell"
	@echo "------------------------------------------------------------------"
	@docker-compose exec nginx /bin/bash

kill-osm:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Deleting all imported OSM data and killing containers"
	@echo "------------------------------------------------------------------"
	@docker-compose kill imposm
	@docker-compose kill osmupdate
	@docker-compose kill osmenrich
	@docker-compose rm imposm
	@docker-compose rm osmupdate
	@docker-compose rm osmenrich
	# Next commands have - in front as they as non compulsory to succeed
	-@sudo rm conf/osm_conf/timestamp.txt
	-@sudo rm conf/osm_conf/last.state.txt
	-@sudo rm conf/osm_conf/importer.lock
	-@docker-compose exec -u postgres db psql -c "drop schema osm cascade;" gis 
	-@docker-compose exec -u postgres db psql -c "drop schema osm_backup cascade;" gis 
	-@docker-compose exec -u postgres db psql -c "drop schema osm_import cascade;" gis 

reinitialise-osm: kill-osm
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Deleting all imported OSM data and reloading"
	@echo "------------------------------------------------------------------"
	@docker-compose up -d imposm osmupdate osmenrich 
	@docker-compose logs -f imposm osmupdate osmenrich

osm-to-mbtiles:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Creating a vector tiles store from the docker osm schema"
	@echo "------------------------------------------------------------------"
        #@docker-compose run osm-to-mbtiles
	@echo "we use below for now because the container aproach doesnt have a new enough gdal (2.x vs >=3.1 needed)"
	@ogr2ogr -f MBTILES osm.mbtiles PG:"dbname='gis' host='localhost' port='15432' user='docker' password='docker' SCHEMAS=osm" -dsco "MAXZOOM=10 BOUNDS=-7.389126,39.410085,-7.381439,39.415144"
	
redeploy-mergin-client:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Stopping merging container, rebuilding the image, then restarting mergin db sync"
	@echo "------------------------------------------------------------------"
	-@docker-compose kill mergin-sync
	-@docker-compose rm mergin-sync
	-@docker rmi mergin_db_sync
	@git clone git@github.com:lutraconsulting/mergin-db-sync.git --depth=1
	@cd mergin-db-sync; docker build --no-cache -t mergin_db_sync .; cd ..
	@rm -rf mergin-db-sync
	@docker-compose --profile=mergin up -d mergin-sync
	@docker-compose --profile=mergin logs -f mergin-sync

reinitialise-mergin-client:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Deleting mergin database schemas and removing local sync files"
	@echo "Then restarting the mergin sync service"
	@echo "------------------------------------------------------------------"
	@docker-compose kill mergin-sync
	@docker-compose rm mergin-sync
	@sudo rm -rf mergin_sync_data/*
	# Next line allowed to fail
	-@docker-compose exec -u postgres db psql -c "drop schema qgis_demo cascade;" gis 
	# Next line allowed to fail
	-@docker-compose exec -u postgres db psql -c "drop schema mergin_sync_base_do_not_touch cascade;" gis 	
	@docker-compose --profile=mergin up -d mergin-sync
	@docker-compose --profile=mergin logs -f mergin-sync

mergin-dbsycn-start:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Starting mergin-db-sync service"
	@echo "------------------------------------------------------------------"
	@docker-compose --profile=mergin up mergin-sync
	@docker-compose --profile=mergin logs -f mergin-sync

mergin-dbsync-logs:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Polling mergin-db-sync logs"
	@echo "------------------------------------------------------------------"
	@docker-compose --profile=mergin logs -f mergin-sync

get-fonts:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Getting Google apache license and gnu free fonts"
	@echo "and placing them into the qgis_fonts volume" 
	@echo "------------------------------------------------------------------"
	-@mkdir fonts
	@cd fonts;wget  https://github.com/google/fonts/archive/refs/heads/main.zip
	@cd fonts;unzip main.zip; rm main.zip
	@cd fonts;wget http://ftp.gnu.org/gnu/freefont/freefont-ttf-20120503.zip
	@cd fonts;unzip freefont-ttf-20120503.zip; rm freefont-ttf-20120503.zip
	@cd fonts;find . -name "*.ttf" -exec mv -t . {} +


odm-clean:
	@echo "------------------------------------------------------------------"
	@echo "Note that the odm_datasets directory should be considered mutable as this script "
	@echo "cleans out all other files"
	@echo "------------------------------------------------------------------"
	@sudo rm -rf odm_datasets/osgisstack/odm*
	@sudo rm -rf odm_datasets/osgisstack/cameras.json
	@sudo rm -rf odm_datasets/osgisstack/img_list.txt
	@sudo rm -rf odm_datasets/osgisstack/cameras.json
	@sudo rm -rf odm_datasets/osgisstack/opensfm
	@sudo rm -rf odm_datasets/osgisstack/images.json

odm-run: odm-clean
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Generating ODM Ortho, DEM, DSM then clipping it and loading it into postgis"
	@echo "Before running please remove any old images from odm_datasets/osgisstack/images"
	@echo "and copy the images that need to be mosaicked into it."
	@echo "Note that the odm_datasets directory should be considered mutable as this script "
	@echo "cleans out all other files"
	@echo "------------------------------------------------------------------"
	@docker-compose run odm

odm-clip:
	@echo "------------------------------------------------------------------"
	@echo "Clippint Ortho, DEM, DSM"
	@echo "------------------------------------------------------------------"
	@docker-compose run odm-ortho-clip
	@docker-compose run odm-dsm-clip
	@docker-compose run odm-dtm-clip

odm-pgraster: export PGPASSWORD = docker
odm-pgraster:
	@echo "------------------------------------------------------------------"
	@echo "Loading ODM products into postgis"
	@echo "------------------------------------------------------------------"
	# Todo - run in docker rather than localhost, currently requires pgraster installed locally
	-@echo "drop schema raster cascade;" | psql -h localhost -p 15432 -U docker gis
	@echo "create schema raster;" | psql -h localhost -p 15432 -U docker gis
	@raster2pgsql -s 32629 -t 256x256 -C -l 4,8,16,32,64,128,256,512 -P -F -I ./odm_datasets/orthophoto.tif raster.orthophoto | psql -h localhost -p 15432 -U docker gis
	@raster2pgsql -s 32629 -t 256x256 -C -l 4,8,16,32,64,128,256,512 -d -P -F -I ./odm_datasets/dtm.tif raster.dtm | psql -h localhost -p 15432 -U docker gis
	@raster2pgsql -s 32629 -t 256x256 -C -l 4,8,16,32,64,128,256,512 -d -P -F -I ./odm_datasets/dsm.tif raster.dsm | psql -h localhost -p 15432 -U docker gis

# Runs above 3 tasks all in one go
odm: odm-run odm-clip odm-pgraster

vrt-styles:
	@echo "------------------------------------------------------------------"
	@echo "Checking out Vector Tiles QMLs to qgis-vector-tiles folder"
	@echo "------------------------------------------------------------------"
	@git clone git@github.com:lutraconsulting/qgis-vectortiles-styles.git

up:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Starting all configured services"
	@echo "------------------------------------------------------------------"
	@source ~/.bashrc; docker-compose up -d

kill:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Killing all containers"
	@echo "------------------------------------------------------------------"
	@docker-compose kill

rm: kill
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Removing all containers"
	@echo "------------------------------------------------------------------"
	@docker-compose rm

nuke:
	@echo
	@echo "------------------------------------------------------------------"
	@echo "Disabling services"
	@echo "This command will delete all your configuration and data permanently."
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo -n "Please type CONFIRM to proceed " && read ans && [ $${ans:-N} = CONFIRM ]
	@echo "------------------------------------------------------------------"
	@echo "Nuking Everything!"
	@echo "------------------------------------------------------------------"
	@docker-compose rm -v -f -s
	@rm .env
	@rm enabled-profiles
	@make site-reset
	@make disable-all-services
	@sudo rm -rf certbot/certbot
	

#######################################################
#  Manage COMPOSE_PROFILES and add it to .bashrc
#######################################################

setup-compose-profile:
	# First remove any existing
	@sed -i '/COMPOSE_PROFILES/d' ~/.bashrc
	# Write the env var to the user's shell
	@echo "export COMPOSE_PROFILES=$$(paste -sd, enabled-profiles)" >> ~/.bashrc
	# Make sure the env var is loaded in their session
	@source ~/.bashrc

remove-compose-profile:
	# First remove any existing
	@sed -i '/COMPOSE_PROFILES/d' ~/.bashrc
	# Make sure the env var is loaded in their session
	@source ~/.bashrc
