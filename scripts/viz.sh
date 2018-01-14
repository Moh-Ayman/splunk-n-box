#!/bin/bash
#       $VERSION: [v4.4-23] $
#       $DATE:    [Sun Dec 31,2017 - 09:21:24PM -0600] $
#       $AUTHOR:  [mhassan2 <mhassan@splunk.com>] $
#
#set -x
#This function build .dot file for graphviz
rm -fr run.dot run.png
gCOUNTER=0    #used to identify cluster number in dot file
#---------------------------------------------------------------------------------
pausing() {
#$1=seconds
#printf "uptime [`uptime`]\n"
for c in $(seq 1 $1); do
    echo -ne "Refreshing in $1 seconds... $c\r"
    sleep 1
done
printf "Refreshing $1 seconds...........\n"

return 0
}   #end pausing()
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
compare() {
string=$1 ; substring=$2

if test "${string#*$substring}" != "$string"
then
      return 0    # $substring is in $string
else
      return 1    # $substring is not in $string
fi
return 0
}   #end compare()
#--------------------------------------------
#--------------------------------------------
is_splunkd_running() {
fullhostname=$1
#if-then-else has reverse boolean representaiton
is_running=`docker exec -ti $1 sh -c "ps xa|grep '[s]plunkd -p'" `
if ( is_container_running "$1" ) && [ -z "$is_running" ]; then   #check if not empty
	return 1    #empty. splunkd not running
else
	return 0    #not empty (splunkd running)
fi
return
}   #end is_splunkd_running()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
is_container_running() {
fullhostname=$1
is_running=`docker ps --format '{{.Names}}' --filter status=running --filter name="$1" `
if [ -z "$is_running" ]; then   #check if not empty
#	echo "$1: not running [ret:0]"
	return 1    #empty(container not runing)
else
#	echo "$1: running [ret:1]"
	return 0    #not empty (container running)
fi
#return
}   #end is_container_running()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function convert_to_linked_hosts() {
# This function fixes the grouping/orientation for graphviz
#input: hostnames string ex [HOST01 HOST02 HOST03 HOST04 HOST 05]
#output: modified strinh with "->" and line breaks by n postion
#ex		SH01-> SH02-> SH03-> SH04 [style="invis"];
#		SH05-> SH06-> SH07 [style="invis"];
#		SH08-> SH09-> SH10 [style="invis"];

#$1: list of hosts to process. DONOT use $host as its global
n=`echo "$1" | awk '{print NF}' `   #hosts count

#printf "DEBUG:($n)convert_to_linked_hosts():IN> hosts:[$1]\n"
list=""
for i in `echo $1`;do
    if [ -z "$list" ];then
        list=$i
    else
        #list=$i"-> $list"  #space is critical
        list="$list-> $i"  #space is critical
    fi
done
#----Break every 5 hosts -----
#NR:Number of fields in record FS:Field Separator RS:Record Separator
#gsub(regexp, replacement [, target])      { gsub(/Britain/, "United Kingdom"); print }
#split string every n word; then append some text
if [ "$n" -gt "5" ]; then
    str=`echo $list | awk '{for(i='5'; i<NF;i+='5'){$i=$i RS}; gsub(RS FS,RS,$0) }1' `
    dot_linkedhosts=`printf "$str"| sed -e ':a' -e 'N' -e '$!ba' -e 's/->\n/ [style=\"invis\"];\\\n /g'`
    dot_linkedhosts=`printf "$dot_linkedhosts [style=\"invis\"];"`
else
    dot_linkedhosts=`printf "$list [style=\"invis\"];"`
fi
#----Break every 5 items -----

#printf "DEBUG:($n)dot_linkedhosts():OUT> dot_linkedhosts:[$dot_linkedhosts]\n"

return    #return global $dot_linkedhosts
}	#end convert_to_linked_hosts()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function build_digraph_section() {
#---Build global stuff -------
n=$1
load=`uptime|awk '{print $11}'`
echo "
//---------------------------------
//generated by build_digraph_section()
digraph test {
splines=false   //false:create strait arrows only
//overlap=false
rankdir=LR
outputorder=nodesfirst
label=\"Splunk N' Box Current Status [total:$n load:$load]\";
#label= <<font color="green">SPLUNK N' BOX STATUS [total:$n load:$load]</font>>
node [	nodesep=1.0,
		rankdir=LR,
		#outputMode=nodesfirst,
		outputorder=nodesfirst
		outputMode=nodesfirst,
		packMode=clust,
		style=rounded,
		penwidth=1.0,
		fontcolor=blue,
		fontsize=10
		shape=box,
		bgcolor=\"#ffffff00\",
		overlap=scale];
   	 	forcelabels=true;
		labelfontcolor=\"Red\"
    	labelfontname=\"Arial\"
    	labelfontsize=\"10\"
    	labelloc=t
    	labeljust=c
    	color=gray;style=filled
    	overlap=prism; overlap_scaling=0.01; ratio=0.7;
edge [penwidth=0.75,arrowsize=0.6]
edge [color=black, fontsize=8, forcelabels=true]
//-------------------------------------" > run.dot
printf "\n" >> run.dot

return
}	#end build_digraph_section()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function format_print_node() {
#This function wrote to dot file with color, title, shape the node based on its condition
name="$1"
role="$2"		#used if supplied to us
#echo "**** name[$name]  role[$role]"
host_ip=`docker inspect --format '{{ .HostConfig }}' "$name"| ggrep -o '[0-9]\+[.][0-9]\+[.][0-9]\+[.][0-9]\+'| head -1`

pendwith=1
if  ! ( is_container_running "$name" ); then      #return=1 if running
        style="rounded,dashed"
		penwidth="1.0"
		color="red"
		label="$name\\\n $host_ip\\\n $role"

elif ! ( is_splunkd_running "$i" ); then
        style="rounded"
		penwidth="2.0"
		color="yellow"
		label="$name\\\n $host_ip\\\n $role"

elif ( compare "$name" "CM" ); then
		style="rounded,bold"
		penwidth="2.0"
		color="greenyellow"
		label="$name\\\n $host_ip\\\n Cluster Master"

elif ( compare "$name" "DEP" ); then
		style="rounded,bold"
		penwidth="2.0"
		color="greenyellow"
		#color="khaki"
		label="$name\\\n $host_ip\\\n Deployer"

elif [ "$name" == "$captain" ]; then
		style="rounded,filled"
		penwidth="2.0"
		#color="limegreen"
		color="salmon"
		#color="khaki"
		label="$name\\\n $host_ip\\\n Captain"

elif ( compare "$name" "SH" ); then
		style="rounded,filled"
		penwidth="2.0"
		#color="palegreen3"
		color="salmon2"
		#color="khaki"
		#echo "$name:$role"
		label="$name\\\n $host_ip\\\n $role"

elif ( compare "$name" "IDX" ); then
		style="rounded,filled"
		penwidth="2.0"
		color="palegreen3"
		#color="khaki"
		label="$name\\\n $host_ip\\\n $role"

elif ( compare "$name" "DEMO" ); then
		style="rounded,filled"
		penwidth="2.0"
		color="hotpink"
		#color="khaki"
		label="$name\\\n $host_ip\\\n $role"

elif ( compare "$name" "MONITOR" ); then
		style="rounded,filled"
		penwidth="2.0"
		color="khaki"
		#color="indianred1"
		label="$name\\\n $host_ip\\\n $role"

else   #everything else
		style="rounded,bold"
		penwidth="2.0"
		color="green"
		label="$name\\\n $host_ip\\\n $role"
fi

line="$name [penwidth=\"$penwidth\", color=\"$color\", style=\"$style\", label=\"$label\"];"
printf "\t$line\n" >> run.dot

return
}	#end formant_print_node()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function build_generic_subgraph() {
generic_members="$1"
#for i in `echo $1`;do      #loop thru all hosts
#	#echo "build_generic_subgraph(): Checking host[$i]...."
#	single=`echo $i|grep -v "SH"|grep -v "IDX" | grep -v "CM"`
#	#members=$members" $single"
#	members=$members" $single"
#	#members="$1"
#done
#printf "hosts[$1]\n"
#printf  "members[$members] \n"
c=`echo "$generic_members" | awk '{print NF}' `   #current number of hosts

    #labelfontcolor=\"turquoise\";" >> run.dot
let gCOUNTER++
echo "//------------------------------------------
//generated by build_generic_subgraph()
subgraph cluster_$gCOUNTER {
label=\"Generic Hosts (non-clustered)\";
	labelloc=t;
	labeljust=c;
	color=blue;		#box color
	style=filled;
	labelfontname=Arial;
	style=rounded;
	fontcolor=Blue;
    labelfontcolor=blue;" >> run.dot

if [ -n "$generic_members" ]; then
	convert_to_linked_hosts "$generic_members"		#returns $dot_linkedhosts
	#printf "DEBUG:dot_linkedhosts:$dot_linkedhosts\n"
	printf "\t$dot_linkedhosts\n" >> run.dot
fi
#note: for if-then-else  0=true   1=false, thats just how it works in bash
#--------change color based on status---------
for i in `echo $generic_members`; do
	format_print_node "$i"
done
#--------change color based on status---------

printf "}\n" >> run.dot
printf "//-----------------------------------\n">> run.dot

return
}	#end build_generic_subgraph()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function build_shc_subgraph() {
#This function build the sch cluster section in dot file.

#dicover shc members,labels and captian--looking for at least 1 SH (container:running splunkd:running)
shc_members="";shc_list="";captain="";dep="";prev_label="";curr_label=""
shc_label_list="";shc_num=o
declare -a shc_record
#----Loop thru all host to build 2D array for each cluster ------
for i in `echo $1`;do      #loop thru ALL system hosts
	#echo "Evaluating [$i]"
	if ( compare  "$i" "SH" ) && ( is_splunkd_running "$i" ); then
   		shc_list=`gtimeout --foreground 10s docker exec -u splunk -ti $i /opt/splunk/bin/splunk show shcluster-status -auth admin:hello| grep -i label|awk '{print $3}'| sort | uniq -c `
		captain=`echo "$shc_list" | grep -v " 1 "| awk '{print $2}'| sed -e 's/^M//g' | tr -d '\r' | tr -d '\n' `
		shc_members=`echo "$shc_list" | awk '{print $2}' |sed -e 's/^M//g' | tr -d '\r' | tr '\n' ' '`
		curr_label=`docker exec -ti $i  sh -c "grep label /opt/splunk/etc/system/local/server.conf"| sed 's/shcluster_label = //g'|sed -e 's/^M//g' | tr -d '\r' | tr '\n' ' '`
		dep_ip=`docker exec -u splunk -ti $i /opt/splunk/bin/splunk list shcluster-config  -auth admin:hello|grep deploy_fetch|sed 's/conf_deploy_fetch_url:https:\/\///g'|sed 's/:8089//g'|sed -e 's/^M//g' | tr -d '\r' | tr '\n' ' '|awk '{print $1}' `
		dep=`docker ps -a|grep "$dep_ip"| awk -F' ' '{print $NF}'` #clean spaces
		curr_label=`echo "$curr_label"| awk -F' ' '{print $NF}'` #clean spaces
		#----------------------------
		#label change means new cluster started.
		if [ "$curr_label" != "$prev_label" ]; then
			shc_label_list="$shc_label_list $curr_label"
		#	echo "$shc_num: label[$curr_label] dep:[$dep] capt:[$captain] members:[$shc_members]"
			write_shc_section "$curr_label" "$dep" "$captain" "$shc_members"
			printf "$shc_members\n" >> shc.tmp
			let shc_num++
		fi  #every four element
		#----------------------------
		prev_label="$curr_label"

	fi #inspecting SH hosts loop

done
#----Loop thru all hosts for each cluster ------

return
}	#end build_shc_subgraph()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function write_shc_section() {
curr_label=$1; dep=$2; captain=$3; shc_members=$4

c=`echo "$shc_members" | awk '{print NF}' `   #current number of hosts
if [ "$c" -gt "0" ]; then
	let gCOUNTER++
	echo "//---------------------------------
//generated by build_shc_subgraph()
subgraph cluster_$gCOUNTER {
	label=\"SEACH HEAD CLUSTER    label:[$curr_label] Hosts:[$c]\";
	labelloc=b;
#	labeljust=r;
    labeljust=c;
	color=lightcyan;	#box color
	fontcolor=Red;
	style=\"rounded,filled\";
    labelfontcolor=\"turquoise\";" >> run.dot
	shc_nodes="$shc_members $dep"
	if [ -n "$shc_nodes" ]; then
		convert_to_linked_hosts "$shc_nodes"		#returns $dot_linkedhosts
		printf "\t$dot_linkedhosts\n" >> run.dot
	fi
	for i in `echo $shc_nodes`; do
		format_print_node "$i" "$role"
	done

	#printf "\t$captain [label=\"CAPTAIN\"];\n" >> run.dot
	printf "}\n" >> run.dot
	printf "//-------------------------\n">> run.dot
	#printf "DEBUG:($n)build_shc_subgraph():OUT> dot_linkedhosts:[$dot_linkedhosts]\n"
fi
return
}	#end write_shc_section()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function write_idxc_section() {
curr_label="$1"; curr_cm="$2"; idxc_members="$3"; cm_list="$4"

#echo "$idxc_num: label[$curr_label] curr_cm:[$curr_cm] members:[$idxc_members]"
c=`echo "$idxc_members" | awk '{print NF}' `   #current number of hosts
if [ "$c" -gt "0" ]; then
	let gCOUNTER++
	echo "//---------------------------------
//generated by build_idxc_subgraph()
subgraph cluster_$gCOUNTER {
	lablefontcolor=\"red\"
	label=\"INDEX CLUSTER   label:[$curr_label]  Hosts:[$c]\";
	//rank=same;
	labelloc=t;
	labeljust=c;
	color=beige;
	style=\"rounded,filled\";
    labelfontcolor=\"turquoise\";" >> run.dot
	idxc_nodes="$idxc_members $curr_cm"
	#printf "{rank=same $idxc_nodes} [style=invis];\n" >> run.dot
	#printf "{rank=same $cm_list} [style=invis];\n" >> run.dot
	#printf "{rankdir=LR $idxc_nodes} [style=invis];\n" >> run.dot
	if [ -n "$idxc_nodes" ]; then
		convert_to_linked_hosts "$idxc_nodes"		#returns $dot_linkedhosts
		printf "\t$dot_linkedhosts\n" >> run.dot
	fi
	for i in `echo $idxc_nodes`; do
		format_print_node "$i" "$role"
	done

	printf "}\n" >> run.dot
	printf "//-------------------------\n">> run.dot
fi
return
}	#end write_idxc_section()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function build_idxc_subgraph() {
#This function build the idxc cluster section in dot file.

#Use CM to dicover the IDXC MEMEBERS
idxc_members=""; curr_cm=""; prev_cm=""; idx_list=""; idxc_nodes=""
idxc_num=0;
for i in `echo $1`;do      #loop thru all hosts
	#echo "Evaluating [$i]"
	#Look for CM in all hosts list
	if  ( compare "$i" "CM" ) && ( is_container_running "$i" ); then
		#echo "build_idxc_subgraph(): Checking host[$i]...."
		curr_cm="$i"   #capture the name
		#---build the idxc members list ----
   		idxc_list=`gtimeout --foreground 10s docker exec -u splunk -ti "$curr_cm" /opt/splunk/bin/splunk show cluster-status -auth admin:hello| grep IDX|awk '{print $1}'| sort | uniq -c `
		#echo "idxc_list> [$idxc_list]"
		idxc_members=`echo "$idxc_list" | awk '{print $2}' |sed -e 's/^M//g' | tr -d '\r' | tr  '\n' ' ' `
		#echo "idxc_members> [$idxc_members]"
		curr_label=`docker exec -ti $i  sh -c "grep label /opt/splunk/etc/system/local/server.conf"| sed 's/shcluster_label = //g'|sed -e 's/^M//g' | tr -d '\r' | tr '\n' ' '`
		curr_label=`echo "$curr_label"| awk -F' ' '{print $NF}'` #clean spaces
		#------------------------------------
		#CM change means new cluster started.
		if [ "$curr_cm" != "$prev_cm" ]; then
			idxc_label_list="$idxc_label_list $curr_label"
			cm_list="$idxc_cm_list $curr_cm"
		#	echo "$idxc_num: label[$curr_label] curr_cm:[$curr_cm] members:[$idxc_members]"
			write_idxc_section "$curr_label" "$curr_cm" "$idxc_members" "$cm_list"
			printf "$idxc_memebers" >> idxc.tmp
			let idxc_num++
		fi  #every four element
		#----------------------------
		prev_cm="$curr_cm"

	fi #inspecting  hosts loop

done
#printf "DEBUG:($n)build_idxc_subgraph():OUT> dot_linkedhosts:[$dot_linkedhosts]\n"
return
}	#end build_idxc_subgraph()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function build_cluster_connections() {
shc_members=""; search_peers=""

printf "\n" >> run.dot
printf "//generated by build_cluster_connections()\n" >> run.dot

#read ALL shc_member groups stored in file create by build_shc_cluster()

while read -u 3 shc_members ; do
	trap "exit" 9 SIGINT SIGTERM SIGKILL
    #echo "Text read from file: $shc_members"
	#shc_memeber should have running containers already
	declare -a shc_array=($shc_members)
	single_sh_host=`echo ${shc_array[0]}`	#we need only one to look up the peers
	search_peers=`docker exec -u splunk -ti $single_sh_host sh -c '/opt/splunk/bin/splunk search "| rest /services/search/distributed/peers | rename status as search_peer_status| table host replicationStatus search_peer_status startup_time "' |egrep  "Initial|Successful" | awk '{print $1":"$3}'`
	search_peers=`echo "$search_peers" |sed -e 's/^M//g' | tr -d '\r' | tr '\n' ' '`  #clean up
	declare -a idxc_array=($search_peers)

	#echo "shc_members[$shc_members]"
	#echo "search_peers[$search_peers]"
	#echo "-------------------------------"

	#rank shc_memebers with idxc_memebers
	if [ -n "$shc_members" ] && [ -n "$search_peers" ]; then
		#printf "{rank=same $shc_members} -> {rank=same $idxc_members} [style=invis]\n" >> run.dot
		shc_array_len=${#shc_array[@]}; idxc_array_len=${#idxc_array[@]}
		for (( i=0; i<${shc_array_len}; i++ )); do
			idx_node=`echo ${idxc_array[$i]} | sed 's/:Up/ /g'| sed 's/:Down/ /g'`
			printf "{rank=same ${shc_array[$i]} $idx_node };\n" >> run.dot
		done
	fi

	#echo "shc_members[$shc_members]"; echo "idxc_members[$idxc_members]"
	#Build cross links (edges)
	for i in `echo $shc_members`; do
		for j in `echo $search_peers`; do
			node_name=`echo $j | sed 's/:Up/ /g'| sed 's/:Down/ /g'`
			node_status=`echo $j | cut -d':' -f2`
			#echo "i[$i] ==> nodename[$node_name] nodestatus[$node_status]"
			if ( compare "$node_status" "Up" ); then
				printf "$i -> $node_name [color=darkgreen;penwidth=1.0];\n" >> run.dot
			else
				printf "$i -> $node_name [color=red;style=dashed;penwidth=1.0];\n" >> run.dot
			fi
		done
		#printf "{rank=same $i $j}\n"
	done

done 3<shc.tmp

rm -fr shc.tmp

printf "//-------------------------\n\n">> run.dot

return
}	#build_cluster_connections()
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
function main_loop() {

hosts=`docker ps -a --format "{{.Names}}"| tr '\n' ' '`
#hosts=`docker ps -a --format "{{.Names}}"| tr '\n' ' '|sed 's/-/_/g'`
n=`echo "$hosts" | awk '{print NF}' `   #current number of hosts
if [ "$n" -eq "0" ]; then
	printf "($n) No hosts listed!\n"
fi

#pharse thru ALL hosts
	build_digraph_section "$n"
 	#order is important
	build_idxc_subgraph "$hosts"
	build_shc_subgraph "$hosts"
	build_generic_subgraph "$hosts"
	build_cluster_connections

#--- close every thing-------
printf "\n}\n\n" >> run.dot
#create png file
dot -Gnewrank -Tpng  run.dot -o run.png
return
}	#end main_loop()
#---------------------------------------------------------------------------------

#### MAIN #####
while true; do
	trap "exit" 9 SIGINT SIGTERM SIGKILL
	trap return
	#tput clear
	#reset   #reset terminal
	clear
	tput sgr0 #; tput cup 0 0
	imgcat run.png
	pausing "5"
	#open run.png
	main_loop
	gCOUNTER=0

done
exit 0
########## END MAIN ###########3




