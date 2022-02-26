#!/bin/bash


json_buf='['

for file in $(find -maxdepth 1 -type f -name '*-order-*-clean*.html' -printf '%P\n' | sort --sort=v) ; do
	#
	# For order price: XML node containing the final price is found from the
	# "money" array thanks to its 'Grand Total' string AND its value bolded.
	# This is because of orders with different money than Euro. In that case,
	# an additional field 'Pay Grand Total' with bolded value appears, and
	# the 'Grand Total' becomes unbolded. Finally, the space character in
	# the string 'Grand Total' is not a standard space
	json_buf="${json_buf}$(xmlstarlet sel -t \
		-m '/html/body/center/table/tbody/tr/td/font' \
		-v "concat('{\"vendor\":\"',table[contains(tbody/tr[2]/td[1], 'Store Name')]/tbody/tr[1]/td[2]/b,'\",\"no\":"$(basename "${file}" | cut -d'-' -f1)",\"price\":',substring-after(table[1]/tbody/tr/td[2]/table/tbody/tr[contains(td[1],\"Grand Total\") and td[2]/b]/td[2]/b, ' '),',\"fees\":', substring-after(table[1]/tbody/tr/td[2]/table/tbody/tr[4]/td[2], ' '), ',\"list\": [')" \
		-m 'table/tbody/tr[td/div/span/a]' \
		-v "concat('{\"type\":\"',substring-before(substring-after(td/div/span/a/@href, '?'),'='),'\",\"id\":\"')" \
		-i "contains(td/div/span/a/@href,'&')" \
		-v "concat(substring-before(substring-after(td/div/span/a/@href, '='),'&'),'\",\"color\":',substring-after(td/div/span/a/@href, 'idColor='), ',')" \
		--else \
		-v "concat(substring-after(td/div/span/a/@href,'='), '\",\"color\":0,')" \
		-b \
		-v "concat('\"qty\":',td[@class = '_bltRightAlign'][1]/text(), ',\"price\":', substring-after(td[@class = '_bltRightAlign'][2]/text(), ' '), ',\"total_price\":', substring-after(td[@class = '_bltRightAlign'][3]/text(), ' ') , '},')" \
		-b \
		-o '{"END_TOKEN": 0}]}' "${file}"),"
done

json_buf="${json_buf}]"

echo $json_buf | sed -e 's/,{"END_TOKEN": 0}//g' -e 's/,]$/]/' | tr -d '$' > orders_hash.json

exit 0
