# CCTC_REDCap_Docker

This project allows you to run REDCap locally in a Docker container. It is implemented using PHP version 8.0.27 and MariaDB version 10.5.16. Use REDCap version 13.8.1.
SSL certificate has been added. The browser may report the site as insecure, but since it is a docker instance it should be okay as the site only runs locally on your computer. 

Update the docker-compose.yml file with the ports you plan on using (if non-standard).
The database connection details are provided in database.php file inside 'www' folder.

Note: to use REDCap versions 10 and 11, or different versions of PHP and MariaDB, modify the docker-compose.yml and Dockerfile.

# Installing REDCap:
1. Create external volume, 'mySQLVolume'. This is used by mariadb container for data persistence. Run the following command in command-line:
    `docker volume create mySQLVolume`
2. Clone the repository
3. Download the REDCap installation file from the community page. When installing REDCap for the first time, download `install.zip` of the version you want to install. Unzip it and copy the contents of 'redcap' folder into the 'www' folder (do not replace database.php file inside 'www' folder).
4. Run the following commands on the command-line:
    `$ docker-compose build`
    `$ docker-compose up -d`
5. Open up the browser and navigate to the following:
    `https://localhost:8443`
    `http://localhost:8080`
6. Follow the instructions for installing REDCap 
7. In Control Center -> File Upload Settings, set LOCAL FILE STORAGE LOCATION as follows:
    `/var/www/html/redcap_file_repository/`
8. To bring down the docker instance, use the command:
    `$ docker-compose down` - best option, preserving any entered data
    `$ docker-compose down -v` - to remove the volume and its data


# Creating Users
Login to the database through MYSQL Workbench and run the scripts in CreateUsers.sql

Database username: root
Database password: root

The scripts create 3 users: 
- test_user
- test_user2
- test_admin

all having the same password: Testing123

After setting the authentication in REDCap to 'Table-based', the users listed can be used for logging in.

# Bringing REDCap up again after initial setup
1.  Open the folder location 'CCTC_REDCap_Docker' (the folder where docker-compose.yml is located) in the command-line and run the following command:
    `$ docker-compose up -d`
2. Open up the browser and navigate to:
    `https://localhost:8443`
    `http://localhost:8080`

# Upgrading REDCap:
1. Download the REDCap installation file from the community page, choosing the upgrade.zip file for the version you want to upgrade to. Unzip it and copy the contents of 'redcap' folder (i.e. redcap_vxx.x.xx folder) into the 'www' folder
2. Open the browser, go to 'Control Center' and press the upgrade button 
    or 
    type the following in the browser:
    `https://localhost:8443/upgrade.php`
    `http://localhost:8080/upgrade.php`

    Note: sometimes if the upgrade.php doesn't work for some reason, try invoking upgrade.php inside the version folder (redcapv_xx.x.xx).
    `https://localhost:8443/redcap_vxx.x.xx/upgrade.php`
    `http://localhost:8080/redcap_vxx.x.xx/upgrade.php`
3. Follow the instructions in the browser to upgrade REDCap
4. Ensure the configuration checks in the ‘Control Center’ pass  
5. Replace the outdated files to root directory after upgrade (redcap_connect.php). This is available as a zip file in the ‘Configuration Check’ link in ‘Control Center’. Unzip it and place it in the www folder. 

# Note: 
1. REDCap 13 requires max_allowed_packet=128M to be added to etc/my.cnf for SQL server. Hence, add the following in docker-compose file: 
    `command: --max_allowed_packet=128M`
2. REDCap version 13 requires installing imagick extension for PHP. After installing this, change the PDF permission to ‘read’ in policy.xml file located in '/etc/ImageMagick-6/’. This is done in Dockerfile.
    `<policy domain="coder" rights="read" pattern="PDF"/>`

# MailHog
Navigate to the following location to see all the emails sent out from REDCap
`http://localhost:8025`

# PhpAdmin
Navigate to the following location to view PHPAdmin
`http://localhost:80`

# Linux 
To get the container id: `docker ps`
To run the Linux container and use bash shell: `docker exec -it <container-id> sh`

