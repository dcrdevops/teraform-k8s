# Procedure for Configuring GitHub OIDC Authentication with AWS for CI/CD Deployment

---

### 1. Create OpenID Connect Provider in AWS

1. Go to **AWS Console → IAM → Identity Providers**.
2. Click **Add provider**.
3. Select **OpenID Connect** as the provider type.
4. Enter the following values:

Provider URL:

```
https://token.actions.githubusercontent.com
```

Audience:

```
sts.amazonaws.com
```

1. Click **Add provider**.

This allows **GitHub Actions workflows** to securely authenticate with AWS without storing long-term credentials.

<img width="1574" height="669" alt="image" src="https://github.com/user-attachments/assets/9b727a85-3d4d-44a6-bf8e-eef75b771db8" />

---

### 2. Create IAM Role for GitHub Actions

1. Go to **IAM → Roles → Create Role**.
2. Select **Web Identity** as the trusted entity type.
3. Choose the provider:

```
token.actions.githubusercontent.com
```

1. Audience:

```
sts.amazonaws.com
```



---

### 3. Configure Trust Policy

Update the role trust relationship with the following policy:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::088310115913:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:Kasadra-Digidense/ci_cd:*"
                }
            }
        }
    ]
}
```

This ensures only workflows from the repository **Kasadra-Digidense/ci_cd** can assume the role.

---

### 4. Attach Required IAM Policies to the Role

Attach the following AWS managed policies:

- AmazonEC2ContainerRegistryFullAccess
- [AdministratorAccess](https://088310115913-yzfvzma4.us-east-1.console.aws.amazon.com/iam/home?region=us-east-1#/policies/details/arn%3Aaws%3Aiam%3A%3Aaws%3Apolicy%2FAdministratorAccess)
- AmazonEC2ContainerRegistryPowerUser
- AmazonEC2FullAccess
- AmazonEKS_CNI_Policy
- AmazonEKSClusterPolicy
- AmazonEKSServicePolicy
- AmazonEKSWorkerNodePolicy
- AmazonS3FullAccess

---

### 5. Add Custom EKS Permissions

Create an inline policy named **cluster-permission** with the following permissions:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:UpdateClusterConfig",
                "eks:CreateAccessEntry",
                "eks:AssociateAccessPolicy"
            ],
            "Resource": "*"
        }
    ]
}
```

This policy allows GitHub Actions to interact with the EKS cluster.

<img width="1578" height="674" alt="image" src="https://github.com/user-attachments/assets/86ee6eb4-26be-4116-a9d0-c04ed02d15dd" />


---

### 6. Use Role in GitHub Actions

In the GitHub workflow, configure AWS credentials using OIDC:

```
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::088310115913:role/<ROLE_NAME>
    aws-region: us-east-1
```

<img width="1274" height="240" alt="image" src="https://github.com/user-attachments/assets/f113b513-bb34-476a-91be-0258b27aea74" />


This allows the GitHub pipeline to securely assume the IAM role and deploy resources to AWS.