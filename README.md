# Mageia linux Official docker images

Scripts and files to create Mageia official docker base images.

http://www.mageia.org


## Build Instructions

  * Use _mkimage.sh_

## How to run the images

Images are available at [docker hub](https://hub.docker.com/_/mageia/), you can use them as this:

    sudo docker pull mageia:latest
    sudo docker run -ti --name mageia mageia bash

Or create your own images that base on this one.
