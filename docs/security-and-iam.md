# 보안 그룹과 IAM 최소 권한 설계


## 역할 구분

| 구분 | Security Group | IAM |
|---|---|---|
| 질문 | 어떤 네트워크 요청을 허용하는가? | 누가 어떤 AWS 작업을 할 수 있는가? |
| 대상 | EC2 네트워크 인터페이스의 통신 | AWS API·콘솔 작업 |
| 예시 | TCP 80은 전체, TCP 22는 관리자 `/32` | 실습 Role에 EC2 생성·종료 권한 |
| 실패 증상 | HTTP/SSH 연결 실패 가능 | `AccessDenied`, `UnauthorizedOperation` |

HTTP 이용자는 IAM 계정이 없어도 공개된 웹 서버에 접근할 수 있다. SSH 인증에는 키페어와 OS 사용자 계정을 사용한다. IAM 권한 확대는 SG 포트 차단을 해결하지 않는다.

## 관리 주체

- Role 이름: `codyssey-lab-operator`. 승인된 학습자만 해당 Role을 수임하도록 신뢰 정책을 제한한다.
- 권한 있는 관리자가 Role을 준비한다. 학습자가 자신의 정책을 확대할 권한은 포함하지 않는다.
- IAM 사용자 방식을 선택한다면 루트와 별개로 만들고 MFA를 적용하며 장기 액세스 키를 불필요하게 발급하지 않는다.
- 모든 리전별 자원은 `ap-northeast-2`에 둔다. IAM Role 자체는 리전별 자원이 아니다.
- EC2에서 정적 Nginx만 실행하므로 instance profile 및 `iam:PassRole` 권한은 이 설계에 필요하지 않다.

## 작업별 권한 범위

| 작업 | 필요한 EC2 API 예시 | 제한 방향 |
|---|---|---|
| 구성 조회 | `DescribeVpcs`, `DescribeSubnets`, `DescribeRouteTables`, `DescribeInstances`, `DescribeSecurityGroups`, `DescribeImages`, `DescribeKeyPairs`, `DescribeVolumes` 등 | 콘솔 흐름에 필요한 조회 작업만 선정 |
| VPC / Subnet | `CreateVpc`, `ModifyVpcAttribute`, `CreateSubnet`, `ModifySubnetAttribute` | 서울 리전, 생성 태그 |
| IGW / 라우팅 | `CreateInternetGateway`, `AttachInternetGateway`, `CreateRouteTable`, `CreateRoute`, `AssociateRouteTable` | 실습 VPC 및 관련 자원 |
| SG | `CreateSecurityGroup`, `AuthorizeSecurityGroupIngress`, `AuthorizeSecurityGroupEgress`, `RevokeSecurityGroupIngress`, `RevokeSecurityGroupEgress` | 실습 SG, 필요한 포트 변경 |
| EC2 / 키페어 | `RunInstances`, `CreateKeyPair`, `CreateTags` | 승인 AMI·서브넷·SG·유형·태그 |
| 정리 | `TerminateInstances`, `DeleteVolume`, `DeleteKeyPair`, `DeleteSecurityGroup`, `DisassociateRouteTable`, `DeleteRoute`, `DeleteRouteTable`, `DeleteSubnet`, `DetachInternetGateway`, `DeleteInternetGateway`, `DeleteVpc` | 생성된 실습 자원만 |


## 정책을 구체화하는 방법

1. 리전 조건을 지원하는 작업에는 `aws:RequestedRegion = ap-northeast-2`를 적용한다.
2. 자원 수준 권한을 지원하는 작업은 대상 ARN으로 제한한다. 생성 시에는 아직 ID가 없으므로 API별 자원 타입과 조건 키를 검토한다.
3. 지원되는 생성 작업에 `aws:RequestTag/Project = codyssey-web`, 기존 자원 작업에 `ec2:ResourceTag/Project = codyssey-web` 등 해당 API가 지원하는 태그 조건을 사용한다.
4. 태그가 유일한 권한 경계라면 임의 자원에 실습 태그를 추가·변경해서 권한을 얻지 못하도록 `CreateTags` / 태그 변경 권한도 제한한다.
5. `RunInstances`는 인스턴스뿐 아니라 AMI·볼륨·네트워크 인터페이스·서브넷·SG·키페어 등 여러 자원 유형에 대한 평가가 필요하므로 인스턴스 ARN 하나만 허용하지 않는다.
6. 자원 수준 제약이 불가능한 조회 작업 등은 `Resource: "*"`가 필요할 수 있다. 이때 Action 자체를 좁힌다. 모든 변경 작업에 일괄 `Resource: "*"`를 주고 최소 권한이라고 표현하지 않는다.

정책 적용 전 지원 조건 키, 필요한 종속 권한, 콘솔의 추가 조회 호출을 확인하고 정책 시뮬레이션 및 제한된 환경에서 검증한다. 이 문서에서는 그 검증을 수행하지 않았다.

근거: [EC2 자격 증명 기반 정책](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-policies-for-amazon-ec2.html), [EC2 API 정책 예시](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ExamplePolicies_EC2.html), [콘솔 권한 예시](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-policies-ec2-console.html).

[README로 돌아가기](../README.md)
