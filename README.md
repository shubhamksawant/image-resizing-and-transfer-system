# AWS-based Automated Image Resizing and Transfer System

This project aims to create an efficient system for managing images on AWS. The objective is to automate image processing tasks, including resizing and transferring images to storage, while ensuring stakeholders receive timely notifications. We leverage key AWS services like Lambda, S3, and SNS to orchestrate this workflow seamlessly.

### Architecture 
![Architecture](/Architecture.drawio.png)

Run following command to run the application
- clone the repo
- run terraform init command
- run terraform plan command { aws_region(default region us-east-1)  & email_address can be provided as variable }
- #run terraform apply command to override default region use below command and update your email id for sns topic 
- terraform apply -var aws_region=us-west-2 email_address=youremail@gmail.com -auto-approve( to approve deployment automatically)
- approve sns topic notification from given email address

application support
- supports png, jpeg, jpg format
- support multi file upload
