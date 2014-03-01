#ifndef DISTRIBUTEDIVDIALOG_H
#define DISTRIBUTEDIVDIALOG_H

#include <QDialog>
#include <QProgressDialog>
#include <QThread>

namespace Ui {
class DistributeDivDialog;
}

class CBitcoinAddress;

class AddrBalanceScanner : public QThread
{
Q_OBJECT

public:

    AddrBalanceScanner(QDialog*parent) : prgDlg(parent)
    {
        setStackSize(1024*1024);
    }

    void Scan(unsigned int _cutoffTime);

    //scanning result
    map<CBitcoinAddress,int64> mapAB;
    std::string errorMsg;
    int nSecsSinceCutoff;

    volatile bool fUserCanceled;
    bool fScanningError;

private:
    unsigned int cutoffTime;
    QProgressDialog prgDlg;


protected:
    void run();
    bool GetAddressBalances();

private slots:

    void receiveScanningProgress(int i,bool fAbort)
    {
        if (fAbort)
        {
            fScanningError=true;
            prgDlg.cancel();
            return;
        }
        if (prgDlg.wasCanceled()) return;
        if (!prgDlg.isVisible()) return;
        prgDlg.setValue(i);
    }

    void onProgressDialogCanceled()
    {
        fUserCanceled=true;
    }

signals:
    void updateScanningProgress(int i,bool fAbort); //called from worker thread
};


struct DummyDistribution
{
    CBitcoinAddress addrPS;
    int64 balPS;
    CBitcoinAddress addrPC;
    int64 dividend;
    int fee;

    static bool biggerBalance(DummyDistribution a,DummyDistribution b)
    {
        return a.balPS > b.balPS;
    }
};

class DistributeDivDialog : public QDialog
{
    Q_OBJECT

public:
    explicit DistributeDivDialog(QWidget *parent = 0);
    ~DistributeDivDialog();

private:

    static const char*columnHeadings[];

    //scanning result
    int nSecsSinceCutoff;
    vector <DummyDistribution> dist;
    void updateTableDisplay();

private:
    Ui::DistributeDivDialog *ui;

protected:
    void resizeEvent(QResizeEvent *qre);
private slots:
    void on_getShareholdsListButton_clicked();
    void on_calcDividendsButton_clicked();

    void on_exportButton_clicked();


};

#endif // DISTRIBUTEDIVDIALOG_H
