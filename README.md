# PRODUCTION GRADE INFRASTRUCTURE IN ONE CLICK ON AWS

Terraform code to deploy a production-grade, multi-environment (Admin, Dev, Prod) Hub-and-Spoke architecture on AWS.

## Prerequisites

* AWS CLI (configured)
* Terraform CLI
* An SSH `.pem` key file

## How to Deploy

### 1. Create the Backend

First, create the S3 bucket that will store the Terraform state.

#### cd backend-setup
#### terraform init
#### terraform apply --auto-approve


**Note:** After this runs, copy the `s3_bucket_name` from the output.

### 2. Deploy the Infrastructure

Now, build the main architecture.

1. Navigate back to the root directory:

2. Open `backend.tf` and paste the S3 bucket name you copied.

3. Create a `terraform.tfvars` file with the path to your key:

private_key_path = "path/to/your/key.pem"

4. Initialize and deploy:

#### terraform init
#### terraform apply --auto-approve


## How to Destroy

Run the destroy commands in the reverse order of creation.

In the root directory
#### terraform destroy --auto-approve

In the backend-setup directory
#### cd backend-setup
#### terraform destroy --auto-approve


