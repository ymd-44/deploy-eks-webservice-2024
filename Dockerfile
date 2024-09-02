FROM ubuntu:18.04

RUN apt update -y apt-get update && apt-get install python3-pip -y && pip3 install flask==2.0.0

ADD server.py /my_server/server.py

WORKDIR /my_server/

EXPOSE 5000

CMD python3 server.py