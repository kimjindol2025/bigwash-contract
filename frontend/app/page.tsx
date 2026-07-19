import styles from './page.module.css';

const findings = [
  {
    id: '01',
    title: '보류 선언과 실행 지시가 한 문서에 같이 살아 있음',
    severity: 'high',
    summary:
      '문서 상단은 2026-07-16에 이 런북 실행을 건너뛰고 Phase 1로 바로 진행했다고 말하지만, 아래 본문은 여전히 T 일정과 Go/No-Go 절차를 현재형으로 지시한다.',
    evidence: [
      '03-phase0-validation-runbook.md:6-8',
      '03-phase0-validation-runbook.md:43-49',
      '03-phase0-validation-runbook.md:123-142',
      '01-product-payment-marketing-plan.md:363-368',
    ],
    impact:
      '독자는 이 문서를 참고용 보존본으로 읽어야 하는지, 지금 따라야 할 운영 런북으로 읽어야 하는지 혼동할 수 있다.',
    fix:
      '상단에 “참고용 / 미실행 보존본” 상태를 더 강하게 표시하고, 본문 일정과 게이트는 비활성 블록으로 분리하는 편이 맞다.',
  },
  {
    id: '02',
    title: '1인 운영 예외를 허용했지만 완료 조건은 여전히 2명 인터뷰 전제임',
    severity: 'medium',
    summary:
      '직원이 없으면 본인이 직접 흐름을 정리하는 대체 경로를 허용하지만, 단계 제목과 산출물은 계속 “내부 담당자 2명 인터뷰”를 기준으로 남아 있다.',
    evidence: [
      '03-phase0-validation-runbook.md:32-33',
      '03-phase0-validation-runbook.md:63-73',
      '03-phase0-validation-runbook.md:131',
    ],
    impact:
      '1인 사업자 기준으로는 예외가 허용된 듯 보이지만, 게이트 문구상 엄밀한 통과 정의는 비어 있다.',
    fix:
      '“2명 인터뷰 또는 1인 자기 업무 분해”로 제목, 완료 조건, 최종 게이트를 같이 수정해야 일관성이 생긴다.',
  },
  {
    id: '03',
    title: '증거 기반 검증인데 `증거 없음`만으로도 완료 처리될 여지가 있음',
    severity: 'medium',
    summary:
      '목적은 네 가지를 증거로 확인하는 것인데, A/S 20건 분석 완료 조건은 각 행에 “증거 참조 또는 증거 없음 표시”만 있으면 형식상 통과할 수 있다.',
    evidence: [
      '03-phase0-validation-runbook.md:12-17',
      '03-phase0-validation-runbook.md:57-61',
    ],
    impact:
      '증거 부족 사례가 많아도 상위 문제 집계가 만들어질 수 있어, 후속 의사결정의 신뢰도가 낮아진다.',
    fix:
      '증거 없는 사례는 별도 보류로 묶거나, 최소 증거 확보 비율을 완료 조건에 추가하는 편이 안전하다.',
  },
];

const summaryCards = [
  {
    label: '문서 성격',
    value: '보류된 런북과 살아 있는 실행 절차가 섞여 있어 상태 분리가 먼저 필요함',
  },
  {
    label: '가장 큰 리스크',
    value: '나중 실행자가 이 문서를 현재 기준 문서로 오독할 가능성',
  },
  {
    label: '권장 정리 순서',
    value: '상태 분리 → 1인 예외 반영 → 증거 기준 강화',
  },
];

export default function Page() {
  return (
    <main className={styles.page}>
      <div className={styles.shell}>
        <section className={styles.hero}>
          <span className={styles.eyebrow}>Runbook Review Tree</span>
          <div className={styles.titleRow}>
            <div>
              <h1 className={styles.title}>Phase 0 검수 결과를 트리 구조로 정리한 페이지</h1>
              <p className={styles.subtitle}>
                <code>03-phase0-validation-runbook.md</code> 검수 결과를 웹에서 바로 읽을 수 있게
                재구성했습니다. 루트에서 문서 상태를 보고, 아래 가지에서 각 결함의 근거와
                영향, 정리 방향을 따라가도록 구성했습니다.
              </p>
            </div>
            <div className={styles.heroMeta}>
              <div className={styles.metaBadge}>검수일 2026-07-19</div>
              <div className={styles.metaBadge}>핵심 이슈 3건</div>
              <div className={styles.metaBadge}>형식: 트리형 리뷰</div>
            </div>
          </div>
        </section>

        <div className={styles.grid}>
          <section className={styles.panel}>
            <h2 className={styles.sectionTitle}>리뷰 트리</h2>
            <p className={styles.sectionLead}>
              루트 판단은 하나입니다. 이 문서는 현재 상태가 분리되지 않아 참고 문서와 실행 문서의
              역할이 충돌합니다. 아래 세 갈래는 그 충돌이 실제로 어디서 발생하는지 보여줍니다.
            </p>

            <div className={styles.tree}>
              <ul className={styles.treeList}>
                <li className={styles.treeItem}>
                  <article className={styles.treeCard}>
                    <div className={styles.treeHeader}>
                      <span className={styles.treeIndex}>R</span>
                      <span className={styles.treeLabel}>Root 판단</span>
                    </div>
                    <div className={styles.treeBody}>
                      <p>
                        <strong>현재 문서는 “보류된 참고본”과 “실행형 런북”이 섞인 상태</strong>라서,
                        나중 실행자가 기준 문서로 오독하기 쉽습니다.
                      </p>
                      <div className={styles.quoteBox}>
                        우선 정리 순서는 상태 분리, 예외 경로 반영, 증거 기준 강화입니다.
                      </div>
                    </div>
                  </article>

                  <ul className={styles.treeList}>
                    {findings.map((finding, index) => (
                      <li key={finding.id} className={styles.treeItem}>
                        <article className={styles.treeCard}>
                          <div className={styles.treeHeader}>
                            <span className={styles.treeIndex}>{index + 1}</span>
                            <span className={styles.treeLabel}>{finding.title}</span>
                            <span
                              className={`${styles.severity} ${
                                finding.severity === 'high'
                                  ? styles.severityHigh
                                  : styles.severityMed
                              }`}
                            >
                              {finding.severity === 'high' ? 'high risk' : 'medium risk'}
                            </span>
                          </div>
                          <div className={styles.treeBody}>
                            <p>{finding.summary}</p>
                            <div className={styles.quoteBox}>
                              <strong>영향</strong>
                              <br />
                              {finding.impact}
                            </div>
                            <div>
                              <strong>근거 위치</strong>
                              <ul className={styles.bulletList}>
                                {finding.evidence.map((item) => (
                                  <li key={item}>{item}</li>
                                ))}
                              </ul>
                            </div>
                            <p>
                              <strong>정리 방향</strong>
                              <br />
                              {finding.fix}
                            </p>
                          </div>
                        </article>
                      </li>
                    ))}
                  </ul>
                </li>
              </ul>
            </div>
          </section>

          <aside className={styles.panel}>
            <h2 className={styles.sectionTitle}>옆가지 요약</h2>
            <p className={styles.sectionLead}>
              페이지 오른쪽에는 실행 판단에 필요한 요점만 따로 뽑아 두었습니다.
            </p>

            <div className={styles.summaryList}>
              {summaryCards.map((card) => (
                <article key={card.label} className={styles.summaryCard}>
                  <span className={styles.summaryLabel}>{card.label}</span>
                  <p className={styles.summaryValue}>{card.value}</p>
                </article>
              ))}
            </div>

            <h2 className={styles.sectionTitle} style={{ marginTop: 28 }}>
              참조 파일
            </h2>
            <ul className={styles.linkList}>
              <li className={styles.linkItem}>
                <a href="../docs/03-phase0-validation-runbook.md">
                  <strong>03-phase0-validation-runbook.md</strong>
                  <span>검수 대상 문서</span>
                </a>
              </li>
              <li className={styles.linkItem}>
                <a href="../docs/01-product-payment-marketing-plan.md">
                  <strong>01-product-payment-marketing-plan.md</strong>
                  <span>상위 결정 문서, 13장 비교 기준</span>
                </a>
              </li>
            </ul>
          </aside>
        </div>
      </div>
    </main>
  );
}
