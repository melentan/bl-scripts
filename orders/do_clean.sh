#!/bin/bash

dir='img/'

move_img() {
	local file=$1
	local item='' new_path=''

	# For each item, move its image
	for item in $(xmlstarlet fo -H -R ${file} 2>/dev/null | xmlstarlet sel -t -m 'html/body/center/table/tbody/tr/td/font/table/tbody/tr[td/div/span/a]' \
		-v 'concat(substring-after(td/div/span/a/@href, "?"),"|item_path=",td/center/a/img/@src)' -n) ; do
		eval "$(echo ${item} | sed -r 's/([IMPS])=([^&]+)(&amp;idColor=([0-9]+))?\|(item_path=.+)/item_type=\1;item_id=\2;item_color=\4;\5/')"
		new_path="${dir}/${item_id}_${item_color}.jpg"
		# If image already exist in the image directory, no need to copy it
		if [[ -e ${new_path} ]] ; then
			continue
		fi

		# Sometimes, there is a .gif image. It has to be converted
		if echo "${item}" | cut -d'|' -f2 | grep -q '\.gif$' ; then
			convert $(echo ${item_path} | sed "s|${dir}|${orig_path}/|") ${new_path}
		else
			cp $(echo ${item_path} | sed "s|${dir}|${orig_path}/|") ${new_path}
		fi
	done
}

do_clean() {
	local file=$1
	local new_file=$(echo ${file} | sed 's/\.html/-clean.html/')

	# Replace all path by "img/"
	local dirpath=$(grep -m 1 'stylesheet.css' ${file} | grep -Eo 'href="[^"]+/' | cut -d\" -f2)
	if [[ -z ${dirpath} ]] ; then
		echo "Error: path of CSS file not found"
		exit 1
	fi

	# Move images to 'img/'
	move_img ${file}
	
	xmlstarlet fo -H -R ${file} 2>/dev/null | xmlstarlet ed -P \
	-d "//script" -d "html/head/style" \
	-d '//comment()' \
	-d 'html/body/center/table/tbody/tr/td/table/tbody/tr/td/font/@face' \
	-u 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/table//text()' -x 'normalize-space()' \
	-d 'html/body/center/table/tbody/tr/td/p' \
	-d 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/center/a/img/@onerror' \
	-d 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/center/font[contains(text(),"*") or contains(text(),"!")]' \
	-d 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/center/br' \
	-d 'html/body/*[position() < count(//body/center/preceding-sibling::*)+1.]' \
	-d 'html/body/center/div[div/a[contains(text(),"Orders Placed")]]' \
	-d '//link[not(contains(@href,"stylesheet.css"))]' \
	-d 'html/body/center/table/tbody/tr/td/font/span[a/strong[contains(text(),"Report problem")]]' \
	-d 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/table/tbody/tr/td/a[contains(@href,"orderBatchID")]' \
	-d 'html/body/center/table/tbody/tr/td/font/table[./tbody/tr/td/input[contains(@value,"Add Order Items To My Wanted List")]]' \
	-d 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td[./font/a[contains(text(),"Send Message")]]' \
	-d 'html/body/center/center[./a/font[contains(text(),"Back to Orders")]]' \
	-d 'html/body/div[contains(@id,"lbOverlay") or contains(@id,"lbMain")]' \
	-u 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td[3]/div/span/a/font/text()' -x 'normalize-space()' \
	-u 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td[contains(@style,"word-wrap: break-word;")]/font/text()' -x 'normalize-space()' \
	-d 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/center/font' \
	-m 'html/body/center/table/tbody/tr/td/center' 'html/body/center/table/tbody/tr/td/font/font' \
	-u 'html/head/link/@href | html/body/center/table/tbody/tr/td/table/tbody/tr/td/a/img/@src | html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/div/span/a/font/div/img/@src | html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/a/img/@src' -x "concat('img/', substring-after(.,'/'))" \
	-u 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/center/a/img/@src[contains(../../../../../td/div/span/a/@href,"&")]' -x "concat('img/',substring-before(substring-after(../../../../../td/div/span/a/@href,'='),'&'),'_',substring-after(../../../../../td/div/span/a/@href, 'idColor='),'.',substring-after(.,'.'))" \
	-u 'html/body/center/table/tbody/tr/td/font/table/tbody/tr/td/center/a/img/@src[not(contains(../../../../../td/div/span/a/@href,"&"))]' -x "concat('img/',substring-after(../../../../../td/div/span/a/@href,'='),'_','.',substring-after(.,'.'))" | \
	xmlstarlet fo | sed -e 's/&amp;quot;/\&quot;/g' >> ${new_file}

}

# Validate each image path
test_check_image() {
	local file=$1

	# For each item, check if its image exists (path validation)
	for item in $(xmlstarlet sel -t -m 'html/body/center/table/tbody/tr/td/font/table/tbody/tr[td/div/span/a]' \
		-v 'concat("item_path=",td/center/a/img/@src)' -n ${file}) ; do
		if [[ ! -f ${file} ]] ; then
			echo "Warning: path ${file} is valid"
		fi
	done
}

if [[ $# -ne 1 ]] ; then
	echo "$0: bad argument"
	exit 1
fi

# If cleaned file already exists, delete it
new_file=$(echo $1 | sed 's/\.html/-clean.html/')
if [[ -f "${new_file}" ]] ; then
	echo "$0: delete already existing file ${new_file}"
	if ! rm "${new_file}" ; then
		exit 1
	fi
fi

do_clean $1

test_check_image ${new_file}

exit 0
