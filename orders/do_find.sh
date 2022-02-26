#!/bin/bash

scriptname=$0
o_hashname='orders_hash.json'
w_hashname='wanted-lists_hash'

source 'libbrick.sh'

OIFS=${IFS}

find_object() {
	local search_id=$1
	local search_color=$2
	local search_date=$3
	local ret=0
	# Idea:
	# - '.[0,-1]': selects the first (0) and last (-1) order
	# - '| .no | tostring': keeps the order number and converts it
	#   as a string (for the later join() call)
	# - '[ ... ]': creates array for the next join() call
	# - 'join(" ")': joins the two numbers in one line
	#local orders_range=$(jq -j '[ (.[0,-1] | .no | tostring) ] | join(" ")' ${o_hashname})

	# Idea:
	# - ".[] as $order": record each order in a variable (used later for matching items)
	# - "$order.list[]": reduce filter to the list of the foreach-ed order
	# - "select(.id==$ID and .color==($COLOR|tonumber)) as $part": filter only id
	#   and color matching items and record them in a variable. "$COLOR|tonumber"
	#   is used because "--arg" option treats its argument as a string, so it has
	#   to be converted
	# - "$order": restore filter in the "order" node position (in order to print
	#   their fields)
	# - Print all wished fields, as well as those of the order ones, than those of the item
	# https://stackoverflow.com/questions/38689645/jq-how-do-i-print-a-parent-value-of-an-object-when-i-am-already-deep-into-the
	#
	# 'tr' is needed in order to remove jq strings quotes
	if ! [ -z ${search_color} ] ; then
		jq --arg ID "${search_id}" --arg COLOR "${search_color}" \
			'.[] as $order | $order.list[] | select(.id==$ID and .color==($COLOR|tonumber)) as $part | $order | "\(.no)|\(.vendor)|\($part.id)|\($part.color)|\($part.qty)|\($part.price)"' \
			${o_hashname} | tr -d '"'
	else
		jq --arg ID "${search_id}" \
			'.[] as $order | $order.list[] | select(.id==$ID) as $part | $order | "\(.no)|\(.vendor)|\($part.id)|\($part.color)|\($part.qty)|\($part.price)"' \
			${o_hashname} | tr -d '"'
	fi

	return $?
}

verbose_find_object() {
	local search_id=$1
	local search_color=$2
	local search_quantity=$3
	local search_date=$4
	local order id color qty price total_price
	local old_order=0
	local min_price=100 max_price=0
	local global_qty=0
	local global_price=0
	local moy=0
	local i=0
	# ${list} is global to return of calling function the prices list
	list=''

	global_min_price=100
	global_max_price=0
	for match in $(find_object ${search_id} ${search_color} ${search_date}) ; do
		order="$(echo ${match} | cut -d'|' -f1)"
		vendor="$(echo ${match} | cut -d'|' -f2)"
		id="$(echo ${match} | cut -d'|' -f3)"
		color="$(echo ${match} | cut -d'|' -f4)"
		qty="$(echo ${match} | cut -d'|' -f5)"
		# Get price, and append zero if it misses in tenth (due to jq)
		price="$(echo ${match} | cut -d'|' -f6 | sed -r 's/\.[0-9]$/&0/')"
		total_price="$(echo "${price} * ${qty}" | bc | sed 's/^\./0./')"
		if [[ ! -z ${search_quantity} ]] ; then
			for ((i=0 ; i < ${qty} ; i++ )) ; do
				list="${list} ${price}"
			done
		fi

		global_min_price=$(min ${price} ${global_min_price})
		global_max_price=$(max ${price} ${global_max_price})
		global_qty=$((${global_qty}+${qty}))
		global_price=$(echo "${global_price}+(${price}*${qty})" | bc | sed 's/^\./0./')
		echo -e "[${blue}${order}-${vendor}${endColor}]" \
			"${yellow}${qty}${endColor} en " \
			"${cyan}$(color_to_string ${color})${endColor}" \
			"(unité: ${yellow}${price}${endColor}, total:" \
			"${yellow}${total_price}${endColor})"
	done

	# Print statistics if at least one match has been found
	if [ -n "${order}" ] ; then
		moy=$(echo "scale=2 ; ${global_price} / ${global_qty}" | bc | sed 's/^\./0./')
		echo -e "-> quantity:${bold_yellow}${global_qty}${endColor}" \
			"min_price:${bold_yellow}${global_min_price}${endColor}" \
			"max_price:${bold_yellow}${global_max_price}${endColor}" \
			"global_price:${bold_yellow}${global_price}${endColor}" \
			"moy_item:${bold_yellow}${moy}${endColor}"
		return 0
	fi
	IFS=${OIFS}

	# No match
	return 1
}

# If no arguments for "find"
if [ $# -lt 1 ] ; then
	echo "${scriptname}: missing argument(s)"
	exit 1
fi
# If there is a second argument
if [ -n "$2" ] ; then
	# Check if argument is an integer
	if echo $2 | grep -Eq '^[0-9]+$' ; then
		# Check if the color name exists
		if ! color_id_exists $2 ; then
			echo "$0: unknown color!"
			exit 1
		fi
		color="$2"
	elif echo $2 | grep -Eq '^[A-Z][A-Za-z\-]+( [A-Z][A-Za-z\-]+)*$' ; then
		# Convert color string to its ID
		color=$(string_to_color "$2")
		if [[ $? -ne 0 ]] ; then
			echo "$0: bad color string ($2)"
			exit 1
		fi
	else
		echo "${scriptname}: bad argument ($2), integer or color name expected"
		exit 1
	fi
else
	color=''
fi
# If there is a third argument
if [[ -n $3 ]] ; then
	# Format checking
	echo "$3" | grep -Eq '[0-9]{2}/[0-9]{2}(/[0-9]{2})?'
	if [[ $? -ne 0 ]] ; then
		echo "$0: bad format ($3)"
		exit 1
	elif [[ $(echo "$3" | cut -d'/' -f1) -gt 12 ]] ; then
		echo "$0: month out of year ($3)"
		exit 1
	elif [[ $(echo "$3" | cut -d'/' -f2) -gt 31 ]] ; then
		echo "$0: day out of month ($3)"
		exit 1
	fi
fi

verbose_find_object $1 ${color} '' $3

exit 0
