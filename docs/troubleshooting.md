# 트러블슈팅 보고서


## 사례 1. 내부 응답은 정상이나 외부 HTTP 연결이 시간 초과

### 증상

외부 PC에서 `curl -i --connect-timeout 5 http://203.0.113.10/health`를 요청하면 연결 시간 초과가 발생한다. SSH는 연결되며 EC2 내부 `curl -i http://localhost/health`는 200과 `OK`를 반환한다.

```text
# 외부 PC
curl: (28) Failed to connect to 203.0.113.10 port 80: Timeout was reached

# EC2 내부
HTTP/1.1 200 OK
Content-Type: text/plain

OK
```

### 가설과 검증

| 가설 | 확인 방법 | 시나리오에서 가정한 관찰 |
|---|---|---|
| Nginx 중단 / localhost에만 바인딩 | `systemctl is-active nginx`, `ss -lntp`, 내부 curl | active, `0.0.0.0:80` LISTEN, 200 |
| 퍼블릭 IP 미할당 | EC2 Networking 확인 | 퍼블릭 IPv4가 있음 |
| IGW 경로 또는 서브넷 연결 오류 | Route Table Routes·Subnet associations, IGW attachment 확인 | 해당 서브넷의 기본 경로와 VPC 연결 정상 |
| SG의 HTTP 규칙 누락 | EC2에 실제 연결된 모든 SG 규칙 확인 | SSH 22 규칙만 있고 HTTP 80 허용 없음 |
| NACL 또는 OS 방화벽 차단 | 서브넷 NACL 양방향, OS 방화벽 규칙 확인 | 기본 허용 NACL, OS의 80 차단 없음 |

### 조치

EC2에 연결된 `codyssey-web-sg`의 인바운드에 **HTTP / TCP / 80 / `0.0.0.0/0`**을 추가하는 절차를 제안한다. SSH는 **TCP 22 / `198.51.100.25/32`**로 유지한다. 전체 포트를 공개하지 않는다.

### 결과

수정 후 같은 외부 PC에서 동일 요청을 반복하면 **HTTP 200 / 본문 OK**가 반환되는 시나리오이다. 이 전후 차이를 통해 SG 규칙 누락이라는 가설을 확인한다.

### 재발 방지

- 인스턴스에 연결된 SG와 편집한 SG가 같은지 확인한다.
- 내부 curl과 외부 curl을 모두 점검 항목에 포함한다.
- HTTP 80 공개와 SSH `/32` 제한을 규칙 표로 검토한다.
- SG 변경 후에는 서비스 응답뿐 아니라 관리 포트 공개 범위도 다시 점검한다.

## 증상 해석의 한계

| 증상 | 우선 확인 | 주의점 |
|---|---|---|
| timeout | SG, NACL, 라우팅, IP, OS 방화벽 | 서비스나 경로의 다른 문제도 가능 |
| connection refused | 리스닝 프로세스, 바인딩 주소, 방화벽 REJECT | 이것만으로 전체 네트워크가 정상이라고 단정하지 않음 |
| 404 | URL, Nginx location, 다른 서버 블록 | HTTP 응답이 오므로 연결 자체와 경로 처리를 나눠 분석 |
| AccessDenied | IAM Action·Resource·Condition·명시적 Deny | HTTP SG 규칙 변경으로 해결되지 않음 |

[README로 돌아가기](../README.md)
