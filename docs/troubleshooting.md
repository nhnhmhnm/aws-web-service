# 트러블슈팅 보고서

> 실제 발생한 장애가 아닌 **가상 환경의 장애 시나리오 분석**이다. 아래 출력·로그·조치 결과는 설명용으로 구성했다.

## 사례 1. 내부 응답은 정상이나 외부 HTTP 연결이 시간 초과

### 증상

외부 PC에서 `curl -i --connect-timeout 5 http://203.0.113.10/health`를 요청하면 연결 시간 초과가 발생한다고 가정한다. SSH는 연결되며 EC2 내부 `curl -i http://localhost/health`는 200과 `OK`를 반환한다.

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

`/var/log/nginx/access.log`에는 해당 외부 요청 기록이 없다고 가정한다. 이는 HTTP 처리 이전 차단 가능성을 뒷받침하지만, 로깅 설정이나 다른 원인도 있어 로그 부재만으로 SG 원인을 확정하지 않는다.

### 조치

EC2에 연결된 `codyssey-web-sg`의 인바운드에 **HTTP / TCP / 80 / `0.0.0.0/0`**을 추가하는 절차를 제안한다. SSH는 **TCP 22 / `198.51.100.25/32`**로 유지한다. 전체 포트를 공개하지 않는다.

### 결과

수정 후 같은 외부 PC에서 동일 요청을 반복하면 **HTTP 200 / 본문 OK**가 반환되는 시나리오이다. 이 전후 차이를 통해 SG 규칙 누락이라는 가설을 확인한다.

### 재발 방지

- 인스턴스에 연결된 SG와 편집한 SG가 같은지 확인한다.
- 내부 curl과 외부 curl을 모두 점검 항목에 포함한다.
- HTTP 80 공개와 SSH `/32` 제한을 규칙 표로 검토한다.
- SG 변경 후에는 서비스 응답뿐 아니라 관리 포트 공개 범위도 다시 점검한다.

## 사례 2. Nginx 설정 오류로 시작 실패

### 증상

EC2·네트워크 설정은 정상으로 가정하지만 Nginx 시작이 실패하고, 내부 `curl localhost/health`도 연결되지 않는다.

### 가설

Nginx 설정 파일의 문법 오류, 80번 포트 충돌, 서비스 중지 가능성을 비교한다.

### 검증

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo journalctl -u nginx -n 30 --no-pager
sudo ss -lntp | grep ':80'
sudo tail -n 30 /var/log/nginx/error.log
```

가상 재현 조건은 `return 200 "OK\n";`에서 끝의 세미콜론을 누락한 것이다. 다음은 이를 설명하기 위한 축약 로그이다.

```text
nginx: [emerg] unexpected "}" in /etc/nginx/nginx.conf:LINE
nginx: configuration file /etc/nginx/nginx.conf test failed
nginx.service: Failed with result 'exit-code'.
```

80번 포트에 다른 프로세스가 없고 `nginx -t`가 실패한다는 조건에서 설정 문법 오류로 원인을 좁힌다.

### 조치

`return 200 "OK\n";`로 문법을 수정하고 `sudo nginx -t`가 성공한 뒤 `sudo systemctl restart nginx`를 실행하는 절차를 제안한다. `sudo systemctl enable nginx`로 부팅 시 시작하도록 구성한다.

### 결과

기대 결과는 `active`, 80번 포트 LISTEN, 내부·외부 `/health` 모두 200 및 `OK`이다.

### 재발 방지

설정 변경마다 `nginx -t`를 선행하고 성공한 경우에만 reload/restart한다. 프로세스 상태와 응답 본문을 함께 확인한다.

## 증상 해석의 한계

| 증상 | 우선 확인 | 주의점 |
|---|---|---|
| timeout | SG, NACL, 라우팅, IP, OS 방화벽 | 서비스나 경로의 다른 문제도 가능 |
| connection refused | 리스닝 프로세스, 바인딩 주소, 방화벽 REJECT | 이것만으로 전체 네트워크가 정상이라고 단정하지 않음 |
| 404 | URL, Nginx location, 다른 서버 블록 | HTTP 응답이 오므로 연결 자체와 경로 처리를 나눠 분석 |
| AccessDenied | IAM Action·Resource·Condition·명시적 Deny | HTTP SG 규칙 변경으로 해결되지 않음 |

[README로 돌아가기](../README.md)
