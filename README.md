# cfgov-job-runner

Utility image for cf.gov maintenance jobs.

## Packaged tools

See [Dockerfile](./Dockerfile) for specific versions.

- [aws](https://aws.amazon.com/cli/)
- [bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell))
- [curl](https://curl.se/)
- [git](https://git-scm.com/)
- [helm](https://helm.sh/)
- [jq](https://jqlang.org/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [python](https://www.python.org/), with extra packages:
  - [boto3](https://pypi.org/project/boto3/)
  - [psycopg[binary]](https://pypi.org/project/psycopg/)
- [yq](https://github.com/mikefarah/yq)

## Usage

### Building the image

```sh
docker build -t cfgov-job-runner:latest .
```

### Checking image tool versions

```sh
docker run --rm -v "$PWD/test-image.sh:/test-image.sh:ro" cfgov-job-runner:latest /test-image.sh
```
