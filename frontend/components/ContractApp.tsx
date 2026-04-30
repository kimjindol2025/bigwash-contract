'use client';

import { useState } from 'react';
import styles from '../styles/contract-app.module.css';

interface ContractItem {
  id: string;
  description: string;
  quantity: number;
  unitPrice: number;
}

interface ContractData {
  number: string;
  clientId: number;
  clientName: string;
  items: ContractItem[];
  amount: number;
  status: 'DRAFT' | 'PENDING' | 'APPROVED' | 'COMPLETED' | 'CANCELLED';
}

export default function ContractApp() {
  const [currentPage, setCurrentPage] = useState('dashboard');
  const [contracts, setContracts] = useState<ContractData[]>([]);
  const [newContract, setNewContract] = useState<Partial<ContractData>>({
    items: [],
    status: 'DRAFT'
  });

  const handleCreateContract = () => {
    if (newContract.clientName && newContract.items?.length > 0) {
      const total = newContract.items.reduce(
        (sum, item) => sum + item.quantity * item.unitPrice,
        0
      );
      const contract: ContractData = {
        number: `CTR-${Date.now()}-${Math.random().toString(36).substr(2, 5).toUpperCase()}`,
        clientId: newContract.clientId || 0,
        clientName: newContract.clientName || '',
        items: newContract.items || [],
        amount: total,
        status: 'DRAFT'
      };
      setContracts([...contracts, contract]);
      setNewContract({ items: [], status: 'DRAFT' });
      setCurrentPage('dashboard');
    }
  };

  const handleAddItem = () => {
    setNewContract({
      ...newContract,
      items: [
        ...(newContract.items || []),
        {
          id: `item-${Date.now()}`,
          description: '',
          quantity: 1,
          unitPrice: 0
        }
      ]
    });
  };

  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <h1 className={styles.logo}>🏢 BigWash Contract</h1>
        <nav className={styles.nav}>
          <button
            className={`${styles.navBtn} ${currentPage === 'dashboard' ? styles.active : ''}`}
            onClick={() => setCurrentPage('dashboard')}
          >
            📊 Dashboard
          </button>
          <button
            className={`${styles.navBtn} ${currentPage === 'new' ? styles.active : ''}`}
            onClick={() => setCurrentPage('new')}
          >
            ✍️ New Contract
          </button>
        </nav>
      </header>

      <main className={styles.main}>
        {currentPage === 'dashboard' && (
          <div className={styles.dashboard}>
            <h2>계약 현황</h2>
            <div className={styles.stats}>
              <div className={styles.statCard}>
                <span className={styles.statLabel}>전체 계약</span>
                <span className={styles.statValue}>{contracts.length}</span>
              </div>
              <div className={styles.statCard}>
                <span className={styles.statLabel}>진행 중</span>
                <span className={styles.statValue}>
                  {contracts.filter(c => c.status === 'PENDING' || c.status === 'DRAFT').length}
                </span>
              </div>
              <div className={styles.statCard}>
                <span className={styles.statLabel}>완료</span>
                <span className={styles.statValue}>
                  {contracts.filter(c => c.status === 'COMPLETED').length}
                </span>
              </div>
            </div>

            <div className={styles.contractList}>
              <h3>최근 계약</h3>
              {contracts.length === 0 ? (
                <p className={styles.empty}>계약이 없습니다.</p>
              ) : (
                <table className={styles.table}>
                  <thead>
                    <tr>
                      <th>계약번호</th>
                      <th>고객명</th>
                      <th>금액</th>
                      <th>상태</th>
                    </tr>
                  </thead>
                  <tbody>
                    {contracts.map((contract) => (
                      <tr key={contract.number}>
                        <td className={styles.contractNumber}>{contract.number}</td>
                        <td>{contract.clientName}</td>
                        <td className={styles.amount}>₩{contract.amount.toLocaleString()}</td>
                        <td>
                          <span className={`${styles.status} ${styles[contract.status.toLowerCase()]}`}>
                            {contract.status}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}

        {currentPage === 'new' && (
          <div className={styles.formContainer}>
            <h2>신규 계약 작성</h2>
            <form className={styles.form}>
              <div className={styles.formGroup}>
                <label>고객명 *</label>
                <input
                  type="text"
                  placeholder="고객 회사명"
                  value={newContract.clientName || ''}
                  onChange={(e) => setNewContract({ ...newContract, clientName: e.target.value })}
                  className={styles.input}
                />
              </div>

              <div className={styles.formGroup}>
                <label>계약 항목</label>
                <div className={styles.itemsContainer}>
                  {(newContract.items || []).map((item, index) => (
                    <div key={item.id} className={styles.itemRow}>
                      <input
                        type="text"
                        placeholder="항목 설명"
                        value={item.description}
                        onChange={(e) => {
                          const updated = [...(newContract.items || [])];
                          updated[index].description = e.target.value;
                          setNewContract({ ...newContract, items: updated });
                        }}
                        className={styles.input}
                      />
                      <input
                        type="number"
                        placeholder="수량"
                        value={item.quantity}
                        onChange={(e) => {
                          const updated = [...(newContract.items || [])];
                          updated[index].quantity = parseInt(e.target.value) || 0;
                          setNewContract({ ...newContract, items: updated });
                        }}
                        className={styles.input}
                        style={{ width: '100px' }}
                      />
                      <input
                        type="number"
                        placeholder="단가"
                        value={item.unitPrice}
                        onChange={(e) => {
                          const updated = [...(newContract.items || [])];
                          updated[index].unitPrice = parseFloat(e.target.value) || 0;
                          setNewContract({ ...newContract, items: updated });
                        }}
                        className={styles.input}
                        style={{ width: '150px' }}
                      />
                      <span className={styles.subtotal}>
                        ₩{(item.quantity * item.unitPrice).toLocaleString()}
                      </span>
                    </div>
                  ))}
                </div>
                <button
                  type="button"
                  onClick={handleAddItem}
                  className={styles.btnSecondary}
                >
                  + 항목 추가
                </button>
              </div>

              <div className={styles.totalAmount}>
                <label>합계</label>
                <span className={styles.amount}>
                  ₩{(newContract.items || [])
                    .reduce((sum, item) => sum + item.quantity * item.unitPrice, 0)
                    .toLocaleString()}
                </span>
              </div>

              <div className={styles.actions}>
                <button type="button" onClick={handleCreateContract} className={styles.btnPrimary}>
                  계약 생성
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setNewContract({ items: [], status: 'DRAFT' });
                    setCurrentPage('dashboard');
                  }}
                  className={styles.btnSecondary}
                >
                  취소
                </button>
              </div>
            </form>
          </div>
        )}
      </main>
    </div>
  );
}
