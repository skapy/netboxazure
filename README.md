# Azure Netbox deployment

**Azure Netbox**

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fskapy%2Fnetboxazure%2Fmaster%2Ftemplate.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fskapy%2Fnetboxazure%2Fmaster%2Fazuredeploy.json)

This template allows you to deploy an Netbox VM using the template installation method. It creates an CentOS 7 VM, does a silent install of Netbox using a modified version of oficial provided documentation ( https://netbox.readthedocs.io/en/stable/ ).


## Initall design and implementation (Sep-2021)

- Added all templates on main page for new VNET and existing VNETs for both two NICs and single NIC.
- Added options to specific your own deployment script and configuration file.


## Overview

This Netbox solution is installed in Centos 7 (Azure Image). 
Here is what you will see when you deploy this Template:


## Design

Here is a visual representation of this design:


## Deployment

Here are few considerations to deploy this solution correctly:

- When you deploy this template, it will leave only TCP 22 listening to Internet while OPNsense gets installed.
- To monitor the installation process during template deployment you can just probe the port 22 on Netbox VM public IP (psping or tcping).

**Note**: It takes about 10 min to complete the whole process when VM is created and a new VM CustomScript is started to install Netbox.

## Usage

- First access can be done using <HTTPS://PublicIP.> Please ignore SSL/TLS errors and proceed.
- Your first login is going to be username "admin" and password privided during template deployment (**PLEASE change your password right the way**).
- To access SSH you can either deploy a Jumpbox VM on Trusted Subnet or create a Firewall Rule to allow SSH to Internet.

## Roadmap

The following improvements will be added soon:
- Add test data load option 

## Feedbacks

Please use Github [issues tab](https://github.com/skapy/netboxazure/issues) to provide feedback.

## Credits

