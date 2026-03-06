SELECT DISTINCT
館別,
CustomerName AS 會員,
Mobile_1 AS 電話,
FullNameInChinese AS 服務人員
FROM (
    SELECT
        CustomerName,
        Mobile_1,
        m.MemberNo,
        CASE m.BelongToBranch
            WHEN 'SE01' THEN '中壢館'
            WHEN 'SE03' THEN '忠孝館'
            WHEN 'SE04' THEN '桃園館'
            WHEN 'SE05' THEN '新竹館'
            WHEN 'SE08' THEN '台中館'
            WHEN 'SE09' THEN '站前館'
            WHEN 'SE12' THEN '板橋館'
            ELSE m.BelongToBranch        
        END AS 館別,
        u.FullNameInChinese,
        CAST(p.PurchaseDate AS Date) AS PurchaseDate,
        ROW_NUMBER() OVER(
            PARTITION BY CONCAT(CustomerName, Mobile_1) 
            ORDER BY p.PurchaseDate DESC
        ) AS rn,
        ISNULL(ProductNo, PackageNo) AS 產品or套組編號,
        ISNULL(pr.NameInChinese, pa.NameInChinese) AS 產品or套組名稱,
        CASE 
            WHEN LEFT(ISNULL(ProductNo, PackageNo), 3) = 'SLT' THEN '高雷'
            WHEN LEFT(ISNULL(ProductNo, PackageNo), 2) = 'SI'  THEN '微整'
            WHEN LEFT(ISNULL(ProductNo, PackageNo), 2) = 'SL'  THEN '雷射'
            WHEN LEFT(ISNULL(ProductNo, PackageNo), 2) = 'SN'  THEN '美容'
            WHEN LEFT(ISNULL(ProductNo, PackageNo), 2) = 'SD'  THEN '美容'
            WHEN LEFT(ISNULL(ProductNo, PackageNo), 2) = 'SS'  THEN '手術'
            ELSE '其他' 
        END AS 療程大類,
        SoldOutPrice,
        m.Birthday,
        DATEDIFF(YEAR, TRY_CAST(m.Birthday AS DATE), GETDATE()) - 
            CASE 
                WHEN (MONTH(TRY_CAST(m.Birthday AS DATE)) > MONTH(GETDATE())) OR 
                     (MONTH(TRY_CAST(m.Birthday AS DATE)) = MONTH(GETDATE()) AND DAY(TRY_CAST(m.Birthday AS DATE)) > DAY(GETDATE())) 
                THEN 1 
                ELSE 0 
            END AS 年齡,
            
        -- 1. 計算「2025年」總消費額
        SUM(CASE 
                WHEN YEAR(p.PurchaseDate) = '2025' THEN SoldOutPrice 
                ELSE 0 
            END) OVER(PARTITION BY CONCAT(CustomerName,Mobile_1)) AS 個人近一年總消費額,
            
        -- 2. 判斷「2025年」是否有買過非手術產品
        MAX(CASE 
                WHEN YEAR(p.PurchaseDate) = '2025'
                     AND LEFT(ISNULL(ProductNo, PackageNo), 2) <> 'SS' THEN 1 
                ELSE 0 
            END) OVER(PARTITION BY CONCAT(CustomerName,Mobile_1)) AS 近一年非手術標記,

        -- [新增] 3. 判斷「兩年內」是否買過核心品項 (買過就標記為 1)
        MAX(CASE WHEN YEAR(p.PurchaseDate) IN ('2024','2025')
                AND ((ISNULL(pr.NameInChinese, pa.NameInChinese) LIKE '%Ellanse%' 
                      OR ISNULL(pr.NameInChinese, pa.NameInChinese) LIKE '%舒顏萃%' 
                      OR ISNULL(pr.NameInChinese, pa.NameInChinese) LIKE '%薇貝拉%' 
                      OR ISNULL(pr.NameInChinese, pa.NameInChinese) LIKE '%艾麗斯%' 
                      OR ISNULL(pr.NameInChinese, pa.NameInChinese) LIKE '%電波%'
                      OR ISNULL(pr.NameInChinese, pa.NameInChinese) LIKE '%音波%')) THEN 1 
                ELSE 0 
            END) OVER(PARTITION BY CONCAT(CustomerName,Mobile_1)) AS 兩年內買過核心品項標記
            
    FROM [dbo].[SaintEir_Purchase] p
    LEFT JOIN [dbo].[SaintEir_PurchaseItem] pi ON p.[PurchaseNo] = pi.[BelongToPurchase]
    LEFT JOIN [dbo].[SaintEir_Product] pr ON pi.[PurchaseProduct] = pr.[ProductKeyNo]
    LEFT JOIN [dbo].[SaintEir_Package] pa ON pi.[PurchasePackage] = pa.[PackageKeyNo]
    LEFT JOIN [dbo].[SaintEir_Member] m ON p.[ByMember] = m.[MemberNo]
    LEFT JOIN [dbo].[PRO2E_AUTH_LOGIN_USER] u ON p.[SoldBy] = u.[LoginName]
    WHERE
        m.BelongToBranch IN ('SE01','SE03','SE04','SE05','SE08','SE09','SE12')
        AND YEAR(p.PurchaseDate) >= '2024'--抓出近兩年是否購買特定產品及最近消費日期
        AND (Mobile_1 IS NOT NULL AND Mobile_1 <> '')
) AS SubQuery
WHERE 
    1=1
    AND 年齡 >= 30  --名單篩選條件3
    AND 個人近一年總消費額 > 200000 --名單篩選條件1
    AND 近一年非手術標記 = 1 -- 名單篩選條件1
    AND 兩年內買過核心品項標記 = 1 -- 名單篩選條件2，1代表有買過特定產品，0代表沒買過
    AND rn = 1 --篩選出最近購買日，回傳call客館別及服務人員
    --AND MemberNo = '80360'
    --AND CustomerName IN('王憶暄')
ORDER BY
會員