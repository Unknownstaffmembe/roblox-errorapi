FROM alpine
COPY ./start-server /bin
RUN apk update
RUN apk add luajit luajit-dev
RUN apk add openssl openssl-dev
RUN apk add sqlite sqlite-dev
RUN apk add bash build-base curl git openssl unzip
RUN apk add bsd-compat-headers
RUN apk add m4
RUN apk add uuidgen

RUN git clone https://github.com/keplerproject/luarocks.git && \
	cd luarocks && \
	sh ./configure && \
	make build install && \
	cd / && \
	rm -rf /luarocks

RUN luarocks install http
RUN luarocks install lua-cjson
RUN luarocks install luasql-sqlite3

RUN cd /root && \ 
	git clone https://github.com/unknownstaffmembe/roblox-errorapi.git

CMD start-server 
