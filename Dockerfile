FROM ubuntu:latest
RUN apt-get update && apt-get upgrade -y
SOURCE 
COPY UserdataScript-phase-2.sh /app/UserdataScript-phase-2.sh
WORKDIR /app
RUN chmod +x UserdataScript-phase-2.sh
CMD echo "Dockerfile succesfully executed. Shell is executing"     