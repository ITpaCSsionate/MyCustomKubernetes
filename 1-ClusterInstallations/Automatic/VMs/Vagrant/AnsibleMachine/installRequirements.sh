#!/bin/bash


function fail {
    for i in {0..9}
    do
        if [[ ${i} -eq 5 ]]
        then
        echo "FAILED ${1}"
        fi
        echo "#####################################################"
    done
    exit
}

function failReturnValue {
    if [[ ${1} -ne 0 ]]
    then
        fail ${2}
    fi
}
id=$(id -u)

if [[ ${id} -ne 0 ]]
then
    fail "id does not match"
fi

## refresh yum cache
returnValue=$(dnf makecache --refresh)
failReturnValue ${returnValue} "dnf makecache"
## yum update
returnValue=$(yum -y update)
failReturnValue ${returnValue} "yum update"
## ensure python3 and python3-pip
returnValue=$(yum install -y python3 python3-pip python3-jinja2)
failReturnValue ${returnValue} "yum installs"


python3 -m pip install virtualenv
echo "installing venv" > /tmp/installed.txt
echo $(which virtualenv) >> /tmp/installed.txt