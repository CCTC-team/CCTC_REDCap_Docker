# CCTC_REDCap_Docker

This docker is used to run REDCap locally. It is implemented using PHP version 7.3.20 and MariaDB version 10.3.35. 

Update the docker-compose.yml file with the ports you plan on using (if non-standard).
The database connection details are provided in database.php file inside 'www' folder.


# Installing REDCap:
1. Clone the repository.
2. Download the REDCap installation file from he community page. When installing REDCap for the first time, download Install.zip of the version you want to install. Unzip it and copy the contents of 'redcap' folder into the 'www' folder (Do not replace database.php file inside 'www' folder).
3. Run the following command:
    $ docker-compose build
    $ docker-compose up -d
4. Open up the browser and type the following
    http://localhost:8080
5. Following the instruction for installing REDCap. 
6. To bring down the docker instance, use the command:
    (to keep volumes): $ docker-compose down
    (to delete volumes): $ docker-compose down -v


# Creating Users
Login to the database through MYSQL Workbench and run the SQL in CreateUsers.sql
Username and Password for the database: root
This SQL creates 3 users (test_user, test_user2, test_admin) all having the same password: Testing123

# Upgrading REDCap:
1. Download the REDCap installation file from the community page. (Choose Upgrade.zip file for the version you want to upgrade to). Unzip it and copy the contents of 'redcap' folder (i.e., redcap_vxx.x.xx folder) into the 'www' folder.
2. Open the browser, go to 'Control Center' and press the upgrade button 
    or 
    type the following in the browser:
    http://localhost:8080/upgrade.php

    Note: sometimes if the upgrade.php doesn't work for some reason, try invoking upgrade.php inside the version folder (redcapv_xx.x.xx).
    http://localhost:8080/redcap_vxx.x.xx/upgrade.php
3. Follow the instructions in the browser to upgrade REDCap.

