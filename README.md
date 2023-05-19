# CCTC_REDCap_Docker
This docker is implemented uses PHP version 7.3.20 and MariaDB version 10.3.35. It is used to run REDCap locally.

Update the docker-compose.yml file with the ports you plan on using (if non-standard).

1. Clone the repository
2. Copy and paste the www folder, used for the installation of REDCap, into the main folder CCTC_REDCap_Docker.
3. Run the following command:
    $ docker-compose build
    $ docker-compose up -d
4. Open up the browser and type the following
    http://localhost:8080
5. Following the instruction for installing REDCap.
6. To bring down the docker instance, use the command:
    $ docker-compose down -v

