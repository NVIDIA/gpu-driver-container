# Driver Container CI

## Deployment

You will need to add these variables to Gitlab CI variables:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `DOCKERHUB_USER`
* `DOCKERHUB_PASSWORD`
* `SSH_PRIVATE_KEY`
* `SSH_HOST_KEY`
* `SSH_HOST_KEY_PUB`

You can also optionally add the `REPOSITORY` variable if you want to deploy to
another repository than Docker Hub.

## Development

You will need jq and terraform installed.


Initialize terraform:
```sh
terraform init
```
