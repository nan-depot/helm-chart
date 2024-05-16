#!/bin/bash

# install argo to argocd namespace
helm install argo argo/ -f argo/values-sandbox.yaml -n argocd --create-namespace

#expose argo to outside ( this script need to call argo api for the following steps, TODO need to improve this to use ingress)
printf "\n =====wait for argo max 60s, expose argoCD api======, this will be replaced with ingress\n"
kubectl wait --timeout=60s --for=condition=Available deployment/argo-argocd-server -n argocd
nohup kubectl port-forward svc/argo-argocd-server 8080:443 -n argocd &

sleep 5

#get argo token
printf "\n ======get argocd token=======\n"
response=$(curl -H 'Content-Type: application/json' https://localhost:8080/api/v1/session -d $'{"username":"admin","password":"password"}' --insecure)
token=$(echo $response | jq -r '.token')

#config argo with git repo (get the username+password from a variable file)
printf "\n =====config repo in argocd======\n"

curl 'https://localhost:8080/api/v1/repositories' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $token" \
  --data-raw '{"type":"git","repo":"https://github.com/nan-depot/helm-chart","username":"nan-depot","password":"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","project":"default"}' \
  --insecure

#add root app to argo
printf "\n ====add app of apps====\n"
curl 'https://localhost:8080/api/v1/applications' \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  --data-raw '{"apiVersion":"argoproj.io/v1alpha1","kind":"Application","metadata":{"name":"apps","finalizers":["resources-finalizer.argocd.argoproj.io"]},"spec":{"destination":{"name":"","namespace":"argocd","server":"https://kubernetes.default.svc"},"source":{"path":"charts/apps","repoURL":"https://github.com/nan-depot/helm-chart","targetRevision":"main"},"sources":[],"project":"default"}}' \
  --insecure


