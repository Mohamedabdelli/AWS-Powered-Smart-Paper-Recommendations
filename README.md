# AWS-Powered Smart Paper Recommendations
This project provides an automated solution for retrieving and recommending scientific papers using advanced cloud services on AWS. It leverages AI models to analyze and suggest relevant articles based on user queries.

## Prerequisites

Before you start, make sure you have the following:

1. **AWS Account**: An active AWS account with the necessary permissions to use the AWS services mentioned.
2. **Pinecone Account**: A Pinecone account for managing vector indexing.

## Project Setup

1. **Clone the Project**

   Clone this repository to your local machine:

   ```bash
   git clone https://github.com/your-username/your-project.git
   cd your-project ```

2. **Configure Terraform**

Create a Terraform configuration file named `terraform.tfvars` at the root of the project with the following content:

```
API_key_pinecone = "change_me"

bucket_name = "change_me"

INDEX_NAME = "change_me"

table_name = "change_me"

hash_key = "id"

billing_mode = "change_me"

SageMaker_endpoint_name = "change_me"

region_name = "us-east-1"
```
3. **Deploy the Infrastructure**
Ensure that you have Terraform installed. Run the following commands to deploy the infrastructure:
```
terraform init
terraform apply --auto-approve
```
