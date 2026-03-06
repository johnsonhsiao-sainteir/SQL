SELECT
CAST(PackageKeyNo AS VARCHAR(50)) AS PackageKeyNo,
PackageNo
FROM [dbo].[SaintEir_Package]
WHERE 
PackageNo IN ('SSF00201','ssf00202')

--Package表查不到的PackageNo，可能是ProductNo，要去Product表查
Select
*
FROM SaintEir_Product
WHERE ProductNo IN ('SSF00201')