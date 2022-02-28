To set up the docker container, first you will need to build the image, to do this you can do
`docker build -t roblox-errorapi .`

You can configure the port number and hostname by editing the file **server.lua**, I also highly recommend attaching a volume to /root/roblox-errorapi/server/db for data persistence or else data will be lost when the container is restarted and, to use a custom server config (**server.lua**) just mount it to ../server/options/server.lua .

Example:
`docker run -d --restart=always -p 127.0.0.1:1337:1337 -v db:/root/roblox-errorapi/server/db:rw roblox-errorapi`
This will map port 1337 on localhost to port 1337 in the container and mount a folder by the name db to the folder **/root/roblox-errorapi/server/db**

If there's an update, just rebuild the docker container (if it doesn't update, try passing the argument --no-cache, e.g. `docker build --no-cache -t roblox-errorapi .`)
