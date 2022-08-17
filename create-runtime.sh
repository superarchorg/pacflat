#!/usr/bin/bash

builddir="build"

# flatpak
runtime="runtime"
runtimedir="$runtime/files"
sdk="sdk"
sdkdir="$sdk/files"
today=$(date +"%Y-%m-%d")
arch="x86_64"
domain="org.superarch"

# ostree
repo="ostree"
remote="superarch"
mode="bare-user-only" # should be archive-z2 when used by root

rm -rf $builddir
mkdir $builddir
cd $builddir

mkdir -p $runtimedir/var/lib/pacman

touch $runtimedir/.ref
ln -s /usr/usr/share $runtimedir/share
ln -s /usr/usr/include $runtimedir/include
ln -s /usr/usr/local $runtimedir/local

mkdir -p $runtimedir/usr/share/fonts
ln -s /run/host/fonts $runtimedir/usr/share/fonts/flatpakhostfonts

mkdir -p $runtimedir/etc
cp /etc/pacman.conf $runtimedir/etc/pacman.conf
sed -i "s/^CheckSpace/#CheckSpace/g" $runtimedir/etc/pacman.conf

echo "installing base in $runtimedir..."
fakechroot fakeroot pacman -Syu --noconfirm --root $runtimedir --dbpath $runtimedir/var/lib/pacman --config $runtimedir/etc/pacman.conf base

echo "generating locales..."
sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" $runtimedir/etc/locale.gen
fakechroot chroot $runtimedir locale-gen

cp -r $runtime $sdk
echo "installing base in $sdkdir..."
fakechroot fakeroot pacman -S --noconfirm --root $sdkdir --dbpath $sdkdir/var/lib/pacman --config $sdkdir/etc/pacman.conf base-devel fakeroot fakechroot --needed

cat << EOF > $runtimedir/metadata
[Runtime]
name=$domain.Platform
runtime=$domain.Platform/$arch/$today
sdk=$domain.Sdk/$arch/$today
EOF

cat << EOF > $sdkdir/metadata
[Runtime]
name=$domain.Sdk
runtime=$domain.Platform/$arch/$today
sdk=$domain.Sdk/$arch/$today
EOF

mkdir $repo
ostree init --mode $mode --repo=$repo

runtime_xa="xa.metadata=$(< $runtimedir/metadata)"$'\n'
sdk_xa="xa.metadata=$(< $sdkdir/metadata)"$'\n'

ostree commit -b runtime/$domain.Platform/$arch/$today --tree=dir=$runtimedir --add-metadata-string "$runtime_xa" --repo=$repo
ostree commit -b runtime/$domain.Sdk/$arch/$today --tree=dir=$sdkdir --add-metadata-string "$sdk_xa" --repo=$repo
ostree summary -u --repo=$repo

flatpak remote-delete --user $remote
cd $repo
flatpak remote-add --user --no-gpg-verify $remote file://$(pwd)

cd ..
