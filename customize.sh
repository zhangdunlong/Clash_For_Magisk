SKIPUNZIP=1

wait_count=0
architecture=""
system_gid="1000"
system_uid="1000"
required_version=""
clash_data_dir="/data/clash"
modules_dir="/data/adb/modules"
ca_path="/system/etc/security/cacerts"
CPFM_mode_dir="${modules_dir}/clash_premium"
mod_config="${clash_data_dir}/clash.config"
geoip_file_path="${clash_data_dir}/Country.mmdb"
wget_https_disable="wget --no-check-certificate"
clash_releases_link="https://github.com/Dreamacro/clash/releases"
geoip_download_link="https://github.com/Hackl0us/GeoIP2-CN/raw/release/Country.mmdb"

if [ -d "${CPFM_mode_dir}" ] ; then
    touch ${CPFM_mode_dir}/disable && ui_print "- CPFM模块在重启后将会禁用."
fi

case "${ARCH}" in
    arm)
        architecture="armv7"
        ;;
    arm64)
        architecture="armv8"
        ;;
    x86)
        architecture="386"
        ;;
    x64)
        architecture="amd64"
        ;;
esac

mkdir -p ${MODPATH}/system/bin
mkdir -p ${clash_data_dir}
mkdir -p ${MODPATH}${ca_path}

if [ ! -f ${geoip_file_path} ] ; then
    ui_print "- 开始下载Country.mmdb."
    ${wget_https_disable} ${geoip_download_link} -O ${geoip_file_path}
    if [ -f ${geoip_file_path} ] ; then
        ui_print "- Country.mmdb下载完成."
    fi
fi

install_core() {
    until (cd ${MODPATH}/system/bin && gzip -d clash.gz && ui_print "- clash内核安装成功.") ; do
        wait_count=$((${wait_count} + 1))

        if [ ${wait_count} -ge 6 ] ; then
            abort "- ! 已尝试下载5次,但是都失败了,检查网络环境或者连接代理后重新尝试."
        fi

        ui_print "- 开始第${wait_count}次下载clash内核."
        ${wget_https_disable} ${clash_releases_link}/download/${required_version}/clash-linux-${architecture}-${required_version}.gz -O ${MODPATH}/system/bin/clash.gz
    done
}

required_version=$(${wget_https_disable} ${clash_releases_link}/latest -q -O - | grep -o "v[0-9]\.[0-9]\.[0-9]" | sort -u)
if [ "$(clash -v | awk '{print $2}')" != "${required_version}" ] ; then
    install_core
fi

unzip -o "${ZIPFILE}" -x 'META-INF/*' -d $MODPATH >&2
if [ "$(md5sum ${MODPATH}/clash.config | awk '{print $1}')" != "$(md5sum ${mod_config} | awk '{print $1}')" ] ; then
    if [ -f "${mod_config}" ] ; then
        mv -f ${mod_config} ${clash_data_dir}/config.backup
        ui_print "- 配置文件有变化，原配置文件已备份为config.backup."
        ui_print "- 建议查看配置文件无误后再重启手机."
    fi
    mv ${MODPATH}/clash.config ${clash_data_dir}/
fi
if [ ! -f "${clash_data_dir}/template" ] ; then
    mv ${MODPATH}/template ${clash_data_dir}/
else
    rm -rf ${MODPATH}/template
fi
mv -f ${MODPATH}/binary/${ARCH}/* ${MODPATH}/system/bin/
mv -f ${MODPATH}/cacert.pem ${MODPATH}${ca_path}
rm -rf ${MODPATH}/binary

if [ ! -f "${clash_data_dir}/packages.list" ] ; then
    touch ${clash_data_dir}/packages.list
fi

sed -i "s/version=latest/version=${required_version}/g" ${MODPATH}/module.prop

sleep 1

ui_print "- 开始设置环境权限."
set_perm_recursive ${MODPATH} 0 0 0755 0644
set_perm  ${MODPATH}/system/bin/setcap  0  0  0755
set_perm  ${MODPATH}/system/bin/getcap  0  0  0755
set_perm  ${MODPATH}/system/bin/getpcaps  0  0  0755
set_perm  ${MODPATH}${ca_path}/cacert.pem 0 0 0644
set_perm  ${MODPATH}/system/bin/curl 0 0 0755
set_perm_recursive ${MODPATH}/scripts ${system_uid} ${system_gid} 0755 0755
set_perm_recursive ${clash_data_dir} ${system_uid} ${system_gid} 0755 0644
set_perm  ${MODPATH}/system/bin/clash  ${system_uid}  ${system_gid}  6755
set_perm  ${clash_data_dir}/clash.config ${system_uid} ${system_gid} 0755
set_perm  ${clash_data_dir}/packages.list ${system_uid} ${system_gid} 0644