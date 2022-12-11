max_containers=6
all_instances_ip_port=""

echo "Clear folders"
rm -r redis-*
echo "OK"


echo "Stoping all containers"
docker stop $(docker ps -a -q)
echo "OK"

echo "Creating docker network"
docker network create redis_cluster
echo "OK"



echo "Creating redis conf files"
for i in `seq 1 $max_containers`
do
echo "."
    dir_name="redis-$i"
    mkdir $dir_name && 
    echo "port 700$i 
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
appendonly yes" > $dir_name/cluster-config.conf
done
echo "OK"

echo "Creating containers"
for i in `seq 1 $max_containers`
do
docker rm redis-$i
docker run -d -v $PWD/redis-$i/cluster-config.conf:/usr/local/etc/redis/redis.conf --name redis-$i -p 700$i:700$i --net redis_cluster redis redis-server /usr/local/etc/redis/redis.conf
done
echo "OK"

echo "Verifying networks"
for i in `seq 1 $max_containers`
do
echo "."
instance_ip=$(docker inspect -f '{{ (index .NetworkSettings.Networks "redis_cluster").IPAddress }}' redis-$i)
instance_port=":700$i"
all_instances_ip_port=$all_instances_ip_port$instance_ip$instance_port" "
done
echo "OK"


max_containers=6
echo "Init cluster"
docker run -i --rm --net redis_cluster redis redis-cli --cluster create $all_instances_ip_port --cluster-replicas 1
echo "OK"

echo "All done"
docker exec -it redis-1 redis-cli -p 7001 cluster nodes