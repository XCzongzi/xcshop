#pragma once

#include <QFileInfo>
#include <QSortFilterProxyModel>
#include <QtQml/qqmlregistration.h>

// Keep view indices and range selection in the same order as the live folder model.
class ElementSortModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool stripExtension MEMBER m_stripExtension)

public:
    explicit ElementSortModel(QObject *parent = nullptr) : QSortFilterProxyModel(parent)
    {
        connect(this, &QAbstractItemModel::rowsInserted, this, &ElementSortModel::countChanged);
        connect(this, &QAbstractItemModel::rowsRemoved, this, &ElementSortModel::countChanged);
        connect(this, &QAbstractItemModel::modelReset, this, &ElementSortModel::countChanged);
        sort(0);
    }

    Q_INVOKABLE QVariant get(int row, const QString &roleName) const
    {
        const auto roles = roleNames();
        for (auto it = roles.cbegin(); it != roles.cend(); ++it) {
            if (it.value() == roleName.toUtf8())
                return data(index(row, 0), it.key());
        }
        return {};
    }

signals:
    void countChanged();

protected:
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override
    {
        const auto roles = sourceModel()->roleNames();
        const int nameRole = roles.key("fileName", Qt::DisplayRole);
        const QString leftFile = sourceModel()->data(left, nameRole).toString();
        const QString rightFile = sourceModel()->data(right, nameRole).toString();
        const QString a = m_stripExtension ? QFileInfo(leftFile).completeBaseName() : leftFile;
        const QString b = m_stripExtension ? QFileInfo(rightFile).completeBaseName() : rightFile;
        // Compare from left to right so names stay grouped. Numeric runs are
        // compared by value, including numbers too large for integer conversion.
        const auto isDigit = [](QChar c) { return c >= u'0' && c <= u'9'; };
        qsizetype i = 0;
        qsizetype j = 0;
        while (i < a.size() && j < b.size()) {
            if (isDigit(a[i]) && isDigit(b[j])) {
                const qsizetype aStart = i;
                const qsizetype bStart = j;
                while (i < a.size() && isDigit(a[i])) ++i;
                while (j < b.size() && isDigit(b[j])) ++j;
                auto x = QStringView(a).mid(aStart, i - aStart);
                auto y = QStringView(b).mid(bStart, j - bStart);
                while (x.size() > 1 && x.front() == u'0') x = x.mid(1);
                while (y.size() > 1 && y.front() == u'0') y = y.mid(1);
                if (x.size() != y.size())
                    return x.size() < y.size();
                const int numericOrder = x.compare(y);
                if (numericOrder)
                    return numericOrder < 0;
            } else {
                const QChar x = a[i++].toCaseFolded();
                const QChar y = b[j++].toCaseFolded();
                if (x != y)
                    return x < y;
            }
        }
        if (i < a.size() || j < b.size())
            return i == a.size();
        // Equivalent names (case or leading zeros) still have a stable order.
        return leftFile < rightFile;
    }

private:
    bool m_stripExtension = false;
};
