# Ciclo 14 · Dia 1 — MDM e mobile: conformidade como regra com evidência, sem tenant

**24/09/2026** · `mdm_compliance.py` · 12 testes · schema `managedDevice` do `$metadata` oficial do Graph (lido hoje) · `qwen2.5:7b` local.

## Rótulo de claim

```text
PROCESSO REAL, SANITIZADO — o processo de preparação e gestão de telemóveis/MDM que o autor
                            operou (mapa de competências, A-07). Sem nome do empregador, sem
                            volumes, sem nome de plataforma interna.
SYNTHETIC LAB             — 8 dispositivos inventados; nomes de campo e valores de enum são os
                            do metadata oficial (complianceState: unknown|compliant|noncompliant|
                            conflict|error|inGracePeriod|configManager; ownerType; enrollmentType).
                            NENHUM tenant Intune; nada executado contra Graph.
```

## APRENDER — o que o portal mostra como cor, aqui é regra

| Regra | Campo oficial | Sev. | O que liga |
|---|---|---|---|
| `NONCOMPLIANT` | `complianceState ∈ {noncompliant, conflict, error}` | HIGH | + sign-in bem-sucedido = a linha da **regra 3 do Ciclo 5** |
| `GRACE_EXPIRED` | `inGracePeriod` com `complianceGracePeriodExpirationDateTime` no passado | HIGH | o portal ainda diz "em graça"; a data diz outra coisa |
| `JAILBROKEN` | `jailBroken == "True"` — **é string no schema**, não boolean | HIGH | um `== true` booleano nunca dispararia |
| `UNENCRYPTED` | `isEncrypted == false` | HIGH | |
| `STALE_SYNC` | `lastSyncDateTime` > 14 d | MEDIUM | "compliant" de há um mês não é compliant |
| `UNREGISTERED` | `azureADRegistered == false` ou `azureADDeviceId` vazio | MEDIUM | **sem chave** para cruzar com `SigninLogs.DeviceDetail.deviceId`: a regra de identidade fica cega para ele |
| `COMPLIANCE_UNKNOWN` | `complianceState == unknown` | MEDIUM | Unknown ≠ compliant (a constante da trilha) |

Cada achado leva `joinKey.azureADDeviceId` — é isso que transforma um inventário MDM em
correlação com identidade (CASE-03/CASE-04).

## TESTAR — 12/12

Inclui: `jailBroken` como string; graça expirada é HIGH, não MEDIUM; `unknown` é achado; o
dispositivo limpo não tem achados; `compliance_pct` conta **dispositivos**, não achados; o
limiar de *stale* é parâmetro.

Sobre o conjunto sintético: 8 dispositivos, 6 com achados, **25 % limpos** — de propósito.

## A IA — 97 s, `invented=0`, `change_intent=0`

Reutilizado o `ai_explain.py` do Ciclo 12 (validador de identificadores alargado a `MDM-*`).
Pela primeira vez na trilha, **todas as verificações eram do domínio certo** (consola MDM,
BitLocker, sign-in logs, eventos de enrolment). Uma dúbia — *"use Xcode to verify jailbreak"* —
inofensiva. Hipótese, não conclusão: o modelo acerta mais quando os achados já trazem `reason`
explícito; a qualidade da entrada é a mitigação mais barata para a qualidade da saída.

## QUEBRAR

- `PERSONAL_PRIVILEGED` depende de prefixo `svc-`/`adm-` — heurística declarada; no conjunto
  não disparou (o único `personal` é um utilizador normal).
- Sem tenant não há `deviceCompliancePolicyState` (a política específica que falhou): o
  `NONCOMPLIANT` diz *que* falhou, não *o quê*. Declarado.

## EXPLICAR

> *"O MDM diz que o dispositivo está 'compliant'. Em que três situações isso não chega — e o
> que é preciso para o cruzar com um sign-in?"*

```text
MARCUS REFLECTION: PENDING
```
