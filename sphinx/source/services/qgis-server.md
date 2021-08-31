# QGIS Server

With the QGIS Server service you can publish one or more QGIS projects including:
1. Projects stored in-database in PostgreSQL
2. Projects stored in the file system

For the QGIS Server, we have chosen the OpenQuake build of QGIS Server because it has a few interesting characteristics. One, is that you can deploy QGIS Server side extensions easily with it and two, it supports things like the QGIS Authentication System. The QGIS Authentication System is an authentication database that provides more advanced securty options, provides PG service support, and provides some special features for url rerouting so that your project paths are hidden away from the user (which is both a security and a convenience concern).  

The OpenQuake QGIS Server is deployed as a QGIS Server instance. The OSGS platform also provides a couple of sample plugins like a demonstrater plugin, the get_info_feature_tidy plugin, and a plugin for handling atlas reports, the atlasprint plugin. The get_info_feature_tidy plugin is a modified version of the GetFeatureInfo handler, and is for tidying up the results of GetFeatureInfo requests. The atlasprint plugin for handling atlas reports, written by 3Liz as a QGIS propriety extension to the WMS service protocol, adds atlas capabilities for getPrint requests in WMS for the QGIS Server. The atlasreport plugin allows you to request a specific page of an altas, a QGIS composed atlas, as the report. This is pretty handy if you, for example, click on a feature and you want to get then from an atlas report the one page that that feauture is covered in the atlas.

Another feature that Docker provides for applications such as QGIS Server is the ability to horizontally scale them. Our platform has some key configuration examples showing you how you can, for example, scale up the QGIS Server instance to have ten concurrently running instances. This is useful for handling increased or high load on the server. It will do like a ram rob(?) and server handler, so that as the requests come in, it will pass each successive request over to the next running instance, and those requests will be handled by that instance, passed back and then that instance will stand by and wait for the next request to come in.

The QGIS Server works in orchestration with many of the other containers, including the PostGIS container. It also works pretty well in conjuction with the SCP (secure copy) container which allows the users of the OSGS architecture to easily move data from their local machine onto the server, either manually by copying and pasting files using an application such as Onescp or using built into Linux file browsers. For example, if you are one the GNOME desktop it has built into SFTP support.

**Service name:** qgis-server

**Project Website:** [QGIS.org](https://qgis.org)

**Project Source Repository:** [QGIS on GitHub](https://github.com/qgis/qgis)

**Project Technical Documentation:** [QGIS on GitHub](https://docs.qgis.org/3.16/en/docs/server_manual/index.html)

**Docker Repository:** [openquake/qgis-server](https://hub.docker.com/r/openquake/qgis-server)

**Docker Source Repository:** [QGIS Server Docker Image](https://github.com/gem/oq-qgis-server) from OpenQuake.



## Configuration

## Deployment

## Enabling

## Disabling

## Accessing the running services

Every project you publish will be available at ```/ogc/project_name``` which makes it very simple to discover where the projects are deployed on the server.

## Additional Notes


## Further Reading

You should read the [QGIS Server documentation](https://docs.qgis.org/3.16/en/docs/server_manual/getting_started.html#) on QGIS.org. It is well written and covers a lot of background explanation which is not provided here. Also you should familiarise yourself with the [Environment Variables](https://docs.qgis.org/3.16/en/docs/server_manual/config.html#environment-variables).

Alesandro Passoti has made a number of great resources available for QGIS Server. See his [workshop slide deck](http://www.itopen.it/bulk/FOSS4G-IT-2020/#/presentation-title) and his [server side plugin examples](https://github.com/elpaso/qgis3-server-vagrant/tree/master/resources/web/plugins), and [more examples here](https://github.com/elpaso/qgis-helloserver).

## QGIS Server Atlas Print Plugin

See the [project documentation](https://github.com/3liz/qgis-atlasprint/blob/master/atlasprint/README.md#api) for supported request parameters for QGIS Atlas prints.

## QGIS Server Scaling

If your server has the needed resources, you can dramatically improve response times for concurrent
QGIS server requests by scaling the QGIS server:

```
docker-compose --profile=qgis-server up -d --scale qgis-server=10 --remove-orphans

```

To take advantage of this, the locations/upstreams/qgis-server.conf should have one server reference per instance e.g.

```
    upstream qgis-fcgi {
        # When not using 'host' network these must reflect the number
        # of containers spawned by docker-compose and must also have
        # names generated by it (including the name of the stack)
        server osgisstack_qgis-server_1:9993;
        server osgisstack_qgis-server_2:9993;
        server osgisstack_qgis-server_3:9993;
        server osgisstack_qgis-server_4:9993;
        server osgisstack_qgis-server_5:9993;
        server osgisstack_qgis-server_6:9993;
        server osgisstack_qgis-server_7:9993;
        server osgisstack_qgis-server_8:9993;
        server osgisstack_qgis-server_9:9993;
        server osgisstack_qgis-server_10:9993;
    }
```


<div class="admonition note">
Scaling to 10 instances is the default if you launch the QGIS server instance via the Make command.
</div>

Then restart Nginx too:

```
docker-compose --profile=production restart nginx

```

Note that if you do an Nginx up it may bring down your scaled QGIS containers so take care.

Finally check the logs of Nginx to make sure things are running right:

```
docker-compose --profile=production logs nginx
```
