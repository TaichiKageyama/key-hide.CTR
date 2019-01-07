#!/bin/sh
ERR=0

key_backup()
{
	local gpg_opt=""
	case $KEY_TYPE in
		"PRI") gpg_opt="--export-secret-keys ${KEY_ID}!";;
		"SUB") gpg_opt="--export-secret-subkeys ${KEY_ID}!";;
	esac

        case $SECRET_DATA_TYPE in
        "TXT")
		gpg $gpg_opt | paperkey --output-type=base16 \
			> $GNUPGHOME/${KEY_ID}.txt ;;
        "QR")
		gpg $gpg_opt | paperkey --output-type=raw | base64 | \
			qrencode -o $GNUPGHOME/${KEY_ID}-qr.png ;;
	"CODE")
		gpg $gpg_opt | paperkey --output-type=raw | \
			base64 > $GNUPGHOME/${KEY_ID}-code.txt ;;
        "BIN")
                gpg $gpg_opt | paperkey --output-type=raw > $GNUPGHOME/${KEY_ID}.bin ;;
        "IMG")
		[ "${IMG_FOR_HIDE}" = "" ] && usage
		local sec_bin=`mktemp`
		gpg $gpg_opt | paperkey --output-type=raw > $sec_bin
                steghide embed -cf $IMG_FOR_HIDE -ef $sec_bin \
			-sf $GNUPGHOME/${KEY_ID}.jpg
		rm -f $sec_bin ;;
        *)
		echo "$SECRET_DATA_TYPE is no supported"
		ERR=1
        esac
}

KEY_SRV=keyserver.ubuntu.com # Good Response
key_restore()
{
	local pub_key=`mktemp -u`
	local sec_data=`mktemp -u`
	local sec_key=`mktemp -u`
	local tmp_img=`mktemp -u`
	local paperkey_input_opt="--input-type=raw"

	# Get Key info from public keyserver
	gpg --keyserver $KEY_SRV --recv-keys $KEY_ID
	# Export key info you want to recovery
	gpg --output $pub_key --export $KEY_ID

	case $SECRET_DATA_TYPE in
	"TXT")  sec_data=$SECRET_DATA
		paperkey_input_opt="--input-type=base16" ;;
	"QR")   # convert data for scan
		convert $SECRET_DATA -resize 640x $tmp_img
		zbarimg --raw $tmp_img | base64 -d > $sec_data ;;
	"CODE") base64 -d $SECRET_DATA > $sec_data ;;
	"BIN")  sec_data=$SECRET_DATA ;;
	"IMG")  steghide extract -sf $SECRET_DATA -xf $sec_data ;;
	esac

	if [ $? -ne 0 ]; then
		ERR=1; return
	fi

	# Revert SECRET_DATA to secret-key
	paperkey --pubring $pub_key --secrets $sec_data \
		$paperkey_input_opt --output $sec_key

	if [ $? -eq 0 ]; then
		gpg --import $sec_key
		echo "Congratulations! Your kery was recovered."
		gpg -K
	else
		echo "Cannot recover your key for GPG" 2>&1
		ERR=1
	fi
}

usage (){
	echo "- You need to -r or -b option"
	echo "- For backup your key:"
	echo "   $ $0 -b -p|-s -t <TXT|QR|CODE|BIN> -k <KEYID>"
	echo "   $ $0 -b -p|-s -t <IMG> -k <KEYID> -i <image>"
	echo "- For restore your key"
	echo "   $ $0 -r -d <BkpData> -t <TXT|QR|CODE|BIN|IMG> -k <KEYID>"
	echo "- You can find KEY_ID with the following command"
	echo "   $ gpg --keyserver keyserver.ubuntu.com --search-keys <mail address>"
	exit 1
}

# main
while getopts rbpsd:t:i:k:h OPT
do
    case $OPT in
	r)  MODE="RESTORE"  ;;
	b)  MODE="BACKUP"   ;;
	p)  KEY_TYPE="PRI"  ;;
	s)  KEY_TYPE="SUB"  ;;
	d)  SECRET_DATA=$OPTARG ;;      # Path of secret-data
	t)  SECRET_DATA_TYPE=$OPTARG ;; # Type of secret-data
	i)  IMG_FOR_HIDE=$OPTARG ;;     # Img data for hiding key
	k)  KEY_ID=$OPTARG ;;           # key ID for backup/restore
        h)  usage ;;
        :|\?) usage ;;
    esac
done

[ "${GNUPGHOME}" = "" ] && GNUPGHOME=$HOME
[ "${KEY_ID}" = "" ] && usage
[ "${SECRET_DATA_TYPE}" = "" ] && usage
[ "${MODE}" = "" ] && usage
[ "${MODE}" = "BACKUP" ] && [ "${KEY_TYPE}" = "" ] && usage

case $MODE in
	"BACKUP")  key_backup ;;
	"RESTORE") key_restore ;;
	*)
		echo "$MODE is not supported";
		ERR=1 ;;
esac

[ $ERR -eq 0 ] && exit 0 || exit 1
