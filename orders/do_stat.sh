#!/bin/bash

# Colors definition
red='\e[0;31m'
green='\e[0;32m'
yellow='\e[0;33m'
bold_yellow='\e[1;33m'
blue='\e[0;34m'
cyan='\e[0;36m'
white='\e[0;37m'
endColor='\e[0m'

# Get :
# - Total of money spent
# - Total quantity
# - Total types of parts
# - Total fees
# - Number of orders
# Each results are wrapped in array in order to use add()
# function (which requires an array as input)
# https://michaelheap.com/sum-values-with-jq/
eval $(jq -j '"total_price=\"\(
	[ .[] | .list[] | .total_price ] | add)\";total_qty=\(
	[ .[] | .list[] | .qty ] | add);total_diff_id=\"\(
	[ .[] | .list[] | .id ] | unique | length)\";total_fees=\"\(
	[ .[] | .fees ] | add)\";total_orders=\(
	. | length)"' orders_hash.json)

# Format total price and fees
LANG=
total_price=$(printf '%.2f\n' ${total_price})
total_fees=$(printf '%.2f\n' ${total_fees})

echo -e "Total cost:${yellow}${total_price}${endColor}" \
	"(charges:${yellow}${total_fees}${endColor}) in" \
	"${yellow}${total_orders}${endColor} orders ;" \
	"${yellow}${total_qty}${endColor} items in" \
	"${yellow}${total_diff_id}${endColor} different types"

# Print stats for each vendor
for v in $(jq -r '[ .[] ] | group_by(.vendor) |
	map(length as $n | "vendor=\"\(
	.[0].vendor)\";total_orders=\(
	$n);total_price=\(
	[ .[].price ] | add)") |
	.[]' orders_hash.json) ; do
	eval ${v}
	
	echo -e "  ${vendor}:${yellow}${total_price}${endColor}" \
		"in ${yellow}${total_orders}${endColor} orders"
done

exit 0
