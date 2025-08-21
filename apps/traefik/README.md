## generate token 


kubectl -n traefik create secret generic traefik-he-ddns --from-literal=HURRICANE_TOKENS='nextmind.net:YOUR_TOKEN'
kubectl -n traefik create secret generic traefik-he-ddns --from-literal=HURRICANE_TOKENS='nextmind.net:YOUR_TOKEN'

## per host 

kubectl -n traefik create secret generic traefik-he-ddns --from-literal=HURRICANE_TOKENS='nextmind.net:YOUR_TOKEN,app.nextmind.net:APP_TOKEN'



VIEA5P5WQB