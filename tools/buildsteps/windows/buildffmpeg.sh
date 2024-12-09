#!/bin/bash

[[ -f buildhelpers.sh ]] &&
    source buildhelpers.sh

FFMPEG_CONFIG_FILE=/xbmc/tools/buildsteps/windows/ffmpeg_options.txt
FFMPEG_VERSION_FILE=/xbmc/tools/depends/target/ffmpeg/FFMPEG-VERSION
FFMPEG_BASE_OPTS="--disable-debug --disable-doc --enable-gpl --enable-w32threads"
FFMPEG_DEFAULT_OPTS=""
FFMPEG_TARGET_OS=mingw32

do_loaddeps $FFMPEG_VERSION_FILE
FFMPEGDESTDIR=$PREFIXwget https://ffmpeg.org/releases/ffmpeg-6.0.1.tar.gz
# wget https://ffmpeg.org/releases/ffmpeg-6.0.1.tar.gz
# echo "945e34840092dc0fd3824eb1af2be79868af2afb4fe13159b19a9bcfc464cc4d53243c13ff065199290e9393ddbf4b1c5c8abccf83a31a31d6c7490e499fd1fc  ffmpeg-6.0.1.tar.gz" | sha512sum -c
# tar -xzf ffmpeg-6.0.1.tar.gz

do_getFFmpegConfig() {
  if [[ -f "$FFMPEG_CONFIG_FILE" ]]; then
    FFMPEG_OPTS_SHARED="$FFMPEG_BASE_OPTS $(cat "$FFMPEG_CONFIG_FILE" | sed -e 's:\\::g' -e 's/#.*//')"
  else
    FFMPEG_OPTS_SHARED="$FFMPEG_BASE_OPTS $FFMPEG_DEFAULT_OPTS"
  fi


  if [ "$ARCH" == "x86_64" ]; then
    FFMPEG_TARGET_OS=mingw64
  elif [ "$ARCH" == "x86" ]; then
    FFMPEG_TARGET_OS=mingw32
    do_addOption "--cpu=i686"
  elif [ "$ARCH" == "arm" ]; then
    FFMPEG_TARGET_OS=mingw32
    do_addOption "--cpu=armv7"
  fi

  # add options for static modplug
  if do_checkForOptions "--enable-libmodplug"; then
    do_addOption "--extra-cflags=-DMODPLUG_STATIC"
  fi

  # handle gplv3 libs
  if do_checkForOptions "--enable-libopencore-amrwb --enable-libopencore-amrnb \
    --enable-libvo-aacenc --enable-libvo-amrwbenc"; then
    do_addOption "--enable-version3"
  fi

  do_removeOption "--enable-nonfree"
  do_removeOption "--enable-libfdk-aac"
  do_removeOption "--enable-nvenc"
  do_removeOption "--enable-libfaac"

  # remove libs that don't work with shared
  do_removeOption "--enable-decklink"
  do_removeOption "--enable-libutvideo"
  do_removeOption "--enable-libgme"
}

do_checkForOptions() {
  local isPresent=1
  for option in "$@"; do
    for option2 in $option; do
      if echo "$FFMPEG_OPTS_SHARED" | grep -q -E -e "$option2"; then
        isPresent=0
      fi
    done
  done
  return $isPresent
}

do_addOption() {
  local option=${1%% *}
  local shared=$2
  if ! do_checkForOptions "$option"; then
    FFMPEG_OPTS_SHARED="$FFMPEG_OPTS_SHARED $option"
  fi
}

do_removeOption() {
  local option=${1%% *}
  FFMPEG_OPTS_SHARED=$(echo "$FFMPEG_OPTS_SHARED" | sed "s/ *$option//g")
}

do_getFFmpegConfig

# enable OpenSSL, because schannel has issues
do_removeOption "--enable-gnutls"
do_addOption "--disable-gnutls"
#do_addOption "--enable-openssl"
do_addOption "--enable-nonfree"
do_addOption "--toolchain=msvc"
do_addOption "--disable-mediafoundation"
do_addOption "--disable-libdav1d"
#do_addOption "--enable-cross-compile"
if [ "$ARCH" == "x86_64" ]; then
  FFMPEG_TARGET_OS=win64
elif [ "$ARCH" = "x86" ]; then
  FFMPEG_TARGET_OS=win32
elif [ "$ARCH" = "arm" ]; then
  FFMPEG_TARGET_OS=win32
fi

export CFLAGS=""
export CXXFLAGS=""
export LDFLAGS=""

extra_cflags="-I$LOCALDESTDIR/include -I/depends/$TRIPLET/include -DWIN32_LEAN_AND_MEAN"
extra_ldflags="-LIBPATH:\"$LOCALDESTDIR/lib\" -LIBPATH:\"$MINGW_PREFIX/lib\" -LIBPATH:\"/depends/$TRIPLET/lib\""
# extra_ldflags="$extra_ldflags -LIBPATH:\"D:\\MicrosoftVisualStudio\\2022\\VC\\Tools\\MSVC\\14.42.34433\\lib\\x86\""
# #extra_ldflags="$extra_ldflags -LIBPATH:\"C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.22621.0\\um\\x86\""

# extra_cflags="-I$LOCALDESTDIR/include -I/depends/$TRIPLET/include -I\"D:\\MicrosoftVisualStudio\\2022\\VC\\Tools\\MSVC\\14.42.34433\\include\" -DWIN32_LEAN_AND_MEAN"

# # 设置 LIB 环境变量
# export LIB="D:\\MicrosoftVisualStudio\\2022\\VC\\Tools\\MSVC\\14.42.34433\\lib\\x86;$LIB"

# #export LIB="C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.22621.0\\um\\x86;$LIB"


# export CFLAGS="$extra_cflags"
# export LDFLAGS="$extra_ldflags"
if [ $win10 == "yes" ]; then
  do_addOption "--enable-cross-compile"
  extra_cflags=$extra_cflags" -MD -DWINAPI_FAMILY=WINAPI_FAMILY_APP -D_WIN32_WINNT=0x0A00"
  extra_ldflags=$extra_ldflags" -APPCONTAINER WindowsApp.lib"
fi

# compile ffmpeg with debug symbols
if do_checkForOptions "--enable-debug"; then
  extra_cflags=$extra_cflags" -MDd"
  extra_ldflags=$extra_ldflags" -NODEFAULTLIB:libcmt"
fi

cd $LOCALBUILDDIR
echo "LOCALBUILDDIR: $LOCALBUILDDIR"
echo "TRIPLET:$TRIPLET"
echo "FFMPEG_TARGET_OS$FFMPEG_TARGET_OS"
echo "FFMPEGDESTDIR:$FFMPEGDESTDIR"
ehco "ARCH:$ARCH"
echo "FFMPEG_OPTS_SHARED:$FFMPEG_OPTS_SHARED"

#do_clean_get $1
# 设置 LOCALSRCDIR 指向手动解压的 FFmpeg 源码目录
LOCALSRCDIR=$LOCALBUILDDIR/ffmpeg-6.0.1

# 检查 LOCALSRCDIR 是否存在
if [ ! -d "$LOCALSRCDIR" ]; then
    echo "Error: FFmpeg source directory not found at $LOCALSRCDIR"
    exit 1
fi

[ -f config.mak ] && make distclean
do_print_status "$LIBNAME-$VERSION (${TRIPLET})" "$blue_color" "Configuring"

[[ -z "$extra_cflags" ]] && extra_cflags=-DPTW32_STATIC_LIB
[[ -z "$extra_ldflags" ]] && extra_ldflags=-static-libgcc

$LOCALSRCDIR/configure --target-os=$FFMPEG_TARGET_OS --prefix=$FFMPEGDESTDIR --arch=$ARCH \
  $FFMPEG_OPTS_SHARED \
  --extra-cflags="$extra_cflags" --extra-ldflags="$extra_ldflags"

do_makelib
exit $?
