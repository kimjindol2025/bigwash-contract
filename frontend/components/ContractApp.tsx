'use client';

import React, { useState } from 'react';
import styles from '../styles/contract-app.module.css';

// 타입 정의
interface ContractItem {
  id: number;
  productName: string;
  quantity: number;
  unitPrice: number;
  amount: number;
}

interface Contract {
  id: string;
  type: string;
  status: 'draft' | 'sent' | 'signed' | 'completed';
  client: string;
  amount: string;
  date: string;
}

// 헤더 컴포넌트
function Header() {
  return (
    <header className={styles.header}>
      <div className={styles.headerContainer}>
        <div className={styles.logoSection}>
          <div className={styles.logo}>
            <span className={styles.logoIcon}>⚡</span>
            <span className={styles.logoText}>BigWash</span>
          </div>
          <span className={styles.logoSubtext}>계약관리</span>
        </div>
        <nav className={styles.nav}>
          <a href="#" className={styles.navLink}>계약서 관리</a>
          <a href="#" className={styles.navLink}>거래명세서</a>
          <a href="#" className={styles.navLink}>설정</a>
        </nav>
        <div className={styles.userSection}>
          <button className={styles.notificationBtn}>
            <span className={styles.notificationIcon}>🔔</span>
            <span className={styles.badge}>2</span>
          </button>
          <div className={styles.userAvatar}>KC</div>
        </div>
      </div>
    </header>
  );
}

// 대시보드 페이지
function DashboardPage() {
  const [filterStatus, setFilterStatus] = useState('all');

  const contracts: Contract[] = [
    {
      id: 'BW-2026-0001',
      client: '(주)세차마을 서울지점',
      type: '장비공급',
      amount: '₩8.5M',
      status: 'signed',
      date: '2026-04-28',
    },
    {
      id: 'BW-2026-0002',
      client: '강남 세차카페',
      type: '설치시공',
      amount: '₩12.3M',
      status: 'sent',
      date: '2026-04-25',
    },
  ];

  return (
    <div className={styles.dashboardContainer}>
      <div className={styles.actionBar}>
        <div>
          <h1 className={styles.pageTitle}>계약서 관리</h1>
          <p className={styles.pageSubtitle}>2026년 4월 기준</p>
        </div>
        <button className={styles.btnPrimary}>
          <span className={styles.btnIcon}>+</span>
          새 계약서 작성
        </button>
      </div>

      <div className={styles.statsGrid}>
        <div className={`${styles.statCard} ${styles.statCardOrange}`}>
          <div className={styles.statLabel}>진행 중</div>
          <div className={styles.statValue}>12</div>
          <div className={styles.statChange}>+2</div>
        </div>
        <div className={`${styles.statCard} ${styles.statCardWarning}`}>
          <div className={styles.statLabel}>서명 대기</div>
          <div className={styles.statValue}>5</div>
        </div>
        <div className={`${styles.statCard} ${styles.statCardSuccess}`}>
          <div className={styles.statLabel}>완료</div>
          <div className={styles.statValue}>127</div>
          <div className={styles.statChange}>+8</div>
        </div>
      </div>

      <div className={styles.listSection}>
        <h2 className={styles.sectionTitle}>최근 계약서</h2>
        <div className={styles.contractTable}>
          <div className={styles.tableHeader}>
            <div className={styles.colContractNo}>계약번호</div>
            <div className={styles.colClient}>거래처</div>
            <div className={styles.colType}>계약유형</div>
            <div className={styles.colAmount}>계약액</div>
            <div className={styles.colStatus}>상태</div>
          </div>
          {contracts.map((contract) => (
            <div key={contract.id} className={styles.tableRow}>
              <div className={styles.colContractNo}>
                <span className={styles.contractNoHighlight}>{contract.id}</span>
              </div>
              <div className={styles.colClient}>{contract.client}</div>
              <div className={styles.colType}>
                <span className={styles.typeBadge}>{contract.type}</span>
              </div>
              <div className={styles.colAmount}>{contract.amount}</div>
              <div className={styles.colStatus}>
                <span className={styles[`status${contract.status.charAt(0).toUpperCase() + contract.status.slice(1)}`]}>
                  {contract.status === 'draft' && '초안'}
                  {contract.status === 'sent' && '발송됨'}
                  {contract.status === 'signed' && '서명됨'}
                  {contract.status === 'completed' && '완료'}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// 신규 계약서 작성 페이지
function NewContractPage() {
  const [formData, setFormData] = useState({
    type: 'supply',
    clientName: '',
    contractDate: new Date().toISOString().split('T')[0],
  });

  const [items, setItems] = useState<ContractItem[]>([
    { id: 1, productName: '', quantity: 1, unitPrice: 0, amount: 0 },
  ]);

  return (
    <div className={styles.formContainer}>
      <div className={styles.formHeader}>
        <h1 className={styles.pageTitle}>새 계약서 작성</h1>
        <p className={styles.pageSubtitle}>계약 정보를 입력하세요</p>
      </div>

      <form className={styles.form}>
        <section className={styles.formSection}>
          <h2 className={styles.sectionTitle}>계약 유형</h2>
          <div className={styles.typeSelector}>
            {[
              { value: 'supply', label: '장비공급', icon: '📦' },
              { value: 'install', label: '설치시공', icon: '🔧' },
              { value: 'maintenance', label: '유지보수', icon: '🛠️' },
              { value: 'repair', label: '수리', icon: '⚙️' },
            ].map((type) => (
              <label key={type.value} className={styles.typeOption}>
                <input
                  type="radio"
                  name="contractType"
                  value={type.value}
                  checked={formData.type === type.value}
                  onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                />
                <span className={styles.typeOptionLabel}>
                  <span className={styles.typeIcon}>{type.icon}</span>
                  <span>{type.label}</span>
                </span>
              </label>
            ))}
          </div>
        </section>

        <section className={styles.formSection}>
          <h2 className={styles.sectionTitle}>거래처 정보</h2>
          <div className={styles.formGrid}>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>거래처명 *</label>
              <input
                type="text"
                placeholder="예: (주)세차마을 서울지점"
                className={styles.formInput}
                value={formData.clientName}
                onChange={(e) => setFormData({ ...formData, clientName: e.target.value })}
              />
            </div>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>계약일 *</label>
              <input
                type="date"
                className={styles.formInput}
                value={formData.contractDate}
                onChange={(e) => setFormData({ ...formData, contractDate: e.target.value })}
              />
            </div>
          </div>
        </section>

        <div className={styles.formActions}>
          <button type="button" className={styles.btnSecondary}>취소</button>
          <button type="submit" className={styles.btnPrimary}>계약서 생성</button>
        </div>
      </form>
    </div>
  );
}

// 메인 앱
export default function ContractApp() {
  const [currentPage, setCurrentPage] = useState('dashboard');

  return (
    <div className={styles.appWrapper}>
      <Header />
      <main className={styles.mainContent}>
        {currentPage === 'dashboard' && <DashboardPage />}
        {currentPage === 'new' && <NewContractPage />}
      </main>
    </div>
  );
}
