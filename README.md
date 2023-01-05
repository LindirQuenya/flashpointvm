# flashpointvm
This repo contains the code that generates the Alpine disk image used by Flashpoint's GameZip server.
More information about what that does and how it works is available [here](https://bluemaxima.org/flashpoint/datahub/GameZIP_Server).

In this file, we will go over the structure and organization of this repo, and give basic instructions for building the image.

## Structure and Organization
 - [.gitignore](.gitignore): This currently ignores all qcow2 images in this directory. This is to prevent us from committing a built image into the file tree.
 - [.github/workflows/build.yml](.github/workflows/build.yml): This automates builds of the image.
 - [Makefile](Makefile): This contains comamnds for building and cleaning up the image.
 - [build.sh](build.sh): This is called by the makefile. It gets and runs the scripts from Alpine that create a standard Alpine VM image. It also does post-processing that shrinks the VM image.
 - [httpd.conf](httpd.conf) and [mime.types](mime.types): Config files for apache.
 - [gamezip](gamezip): This is an openrc service definition. It contains the commands for mounting and unmounting AVFS and UnionFS.
 - [needed_mods.txt](needed_mods.txt): This is a list of all the kernel modules needed for our VM to run. There might be some extras that we don't need still on there. I just stopped removing modules when it broke.
 - [setup.sh](setup.sh): This is run (chroot-ed, I think) inside the base VM image. It sets up all the things we need, and removes the things we don't.
 - [snapshot.sh](snapshot.sh): This takes a running snapshot of the VM, so that starting it up when Flashpoint runs is much faster.

 ## Building
 To build the image, `cd` into this directory, and run `sudo make`. That's it! Let the script run. DO NOT interrupt the script. It can end up running commands from `setup.sh` on your system, which can be quite catastrophic. An unfortunate developer once deleted half his kernel modules this way.

 To run the snapshot, run:
  - `export QEMU_EXTRA_ARGS="-machine pc-i440fx-5.2"`
  - `sudo ./snapshot.sh`

  The sudo on that last command isn't needed if your user has the proper permissions. (e.g. is part of the kvm group)

  To test your newly-built image, copy alpine.qcow2 and snapshot.7z from this directory to the Server/ folder in an existing Flashpoint installation. Options can be adjusted in Data/services.json if needed.
