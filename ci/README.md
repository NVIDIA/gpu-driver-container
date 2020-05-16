# Driver Container CI

## Deployment

You will need to add these variables to Gitlab CI variables:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `REGISTRY_USER`
* `REGISTRY_TOKEN`
* `SSH_PRIVATE_KEY`

You can also optionally add the `REGISTRY` variable if you want to deploy to
another docker registry than Docker Hub.

### AWS account

The AWS account only needs permissions to create EC2 instances and new IAMs to
store its key pairs.

### Generate SSH keys

To ensure the security of the SSH connection, you must generate a host key pair
and a client key pair which you will store in Gitlab CI variables.

Generate the client key pair (`SSH_PRIVATE_KEY`):

```
ssh-keygen -t rsa -b 4096 -f id_rsa
```

## Development

You will need jq and terraform installed.


Initialize terraform:
```sh
terraform init
```
