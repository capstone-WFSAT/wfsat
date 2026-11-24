# arp_spoofing — ARP 스푸핑(중간자, MITM)

LAN 에서 **ARP 에 인증이 없다**는 점을 악용한다. 피해자에게는 "게이트웨이 =
공격자 MAC", 게이트웨이에는 "피해자 = 공격자 MAC" 이라고 위조 ARP 를 반복
주입하면, 둘 사이 트래픽이 공격자를 거쳐 흐른다(MITM). `ip_forward` 를 켜 두므로
피해자는 인터넷이 그대로 되는 것처럼 보인다.

**핵심 도구:** `arpspoof` (dsniff)

## 동작 개요

```
피해자 ─(원래)─▶ 게이트웨이
   │  위조 ARP: "게이트웨이는 나(공격자)"
   ▼
피해자 ──▶ 공격자 ──중계──▶ 게이트웨이 ──▶ 인터넷
           ▲ 위조 ARP: "피해자는 나(공격자)"
```

## 요구 도구

`dsniff`(arpspoof), `ip`. `sudo bash et_check_deps.sh` 로 점검/설치.

## 실행

```bash
# 피해자 IP 만 주면 게이트웨이/인터페이스는 기본 라우트에서 자동 감지
sudo ARP_TARGET=192.168.10.24 bash arp_spoofing/et_arp_spoof.sh

# 전부 지정
sudo ARP_TARGET=192.168.10.24 ARP_GATEWAY=192.168.10.1 ARP_IFACE=eth0 \
     bash arp_spoofing/et_arp_spoof.sh
```

| env | 기본값 | 설명 |
|---|---|---|
| `ARP_TARGET` | (필수) | 피해자 IP |
| `ARP_GATEWAY` | 기본 라우트 게이트웨이 | 게이트웨이 IP |
| `ARP_IFACE` | `interface` > 기본 라우트 NIC | 공격 인터페이스 |

종료는 **Ctrl+C**(또는 `stop`). arpspoof 가 정상 ARP 를 재전송해 피해자/게이트웨이
ARP 테이블을 복구하고, `ip_forward` 도 원래 값으로 되돌린다.

중계되는 트래픽 확인 예:
```bash
sudo tcpdump -i <ARP_IFACE> host <ARP_TARGET>
```

## 대시보드 연동

`et_logger.sh` 로 `attack_start` · `client_connected`(피해자) · `attack_stop` 을
기록해 실습 탭 상태/이벤트 카드에 표시된다.

> ⚠️ 본인이 소유하거나 명시적으로 허가받은 격리된 실습 환경에서만 사용할 것.
