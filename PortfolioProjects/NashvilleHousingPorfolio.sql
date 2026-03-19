SELECT *
FROM PortfolioProject2..NashvilleHousing
--WHERE PropertyAddress is NULL



--Cleaning SaleDate Format

SELECT SaleDateConverted, CONVERT(DATE, SaleDate)
FROM PortfolioProject2..NashvilleHousing

UPDATE NashvilleHousing
SET SaleDate = CONVERT(Date, SaleDate)

ALTER TABLE NashvilleHousing
ADD SaleDateConverted Date;

UPDATE NashvilleHousing
SET SaleDateConverted = CONVERT(Date, SaleDate)

--Populating Null PropertyAddress

SELECT Q1.ParcelID, Q1.PropertyAddress, Q2.ParcelID, Q2.PropertyAddress, ISNULL(Q1.PropertyAddress, Q2.PropertyAddress) AS FixedPropertyAddress 
FROM PortfolioProject2..NashvilleHousing Q1
JOIN PortfolioProject2..NashvilleHousing Q2
	ON Q1.ParcelID = Q2.ParcelID
	AND Q1.[UniqueID ] != Q2.[UniqueID ]
WHERE Q1.PropertyAddress is NULL


UPDATE Q1
SET PropertyAddress = ISNULL(Q1.PropertyAddress, Q2.PropertyAddress)
FROM PortfolioProject2..NashvilleHousing Q1
JOIN PortfolioProject2..NashvilleHousing Q2
	ON Q1.ParcelID = Q2.ParcelID
	AND Q1.[UniqueID ] != Q2.[UniqueID ]
WHERE Q1.PropertyAddress is NULL

--Parsing PropertyAddress

SELECT PropertyAddress
FROM PortfolioProject2..NashvilleHousing

SELECT 
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS Address
, SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, Len(PropertyAddress)) AS CityAddress

FROM PortfolioProject2..NashvilleHousing

ALTER TABLE NashvilleHousing
ADD PropertySplitAddress nvarchar(255);

UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1)

ALTER TABLE NashvilleHousing
ADD CityAddress Nvarchar(255);

UPDATE NashvilleHousing
SET CityAddress = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, Len(PropertyAddress))

SELECT *
FROM PortfolioProject2..NashvilleHousing



--Parsing Owneraddress

SELECT OwnerAddress
FROM PortfolioProject2..NashvilleHousing


SELECT
PARSENAME(REPLACE(OwnerAddress,',', '.'),3),
PARSENAME(REPLACE(OwnerAddress,',', '.'),2),
PARSENAME(REPLACE(OwnerAddress,',', '.'),1)
FROM PortfolioProject2..NashvilleHousing

ALTER TABLE NashvilleHousing
ADD OwnerStreetAddress nvarchar(255);

UPDATE NashvilleHousing
SET OwnerStreetAddress = PARSENAME(REPLACE(OwnerAddress,',', '.'),3)
FROM PortfolioProject2..NashvilleHousing

ALTER TABLE NashvilleHousing
ADD OwnerCityAddress nvarchar(255);

UPDATE NashvilleHousing
SET OwnerCityAddress = PARSENAME(REPLACE(OwnerAddress,',', '.'),2)
FROM PortfolioProject2..NashvilleHousing

ALTER TABLE NashvilleHousing
ADD OwnerStateAddress nvarchar(255);

UPDATE NashvilleHousing
SET OwnerStateAddress = PARSENAME(REPLACE(OwnerAddress,',', '.'),1)
FROM PortfolioProject2..NashvilleHousing

SELECT OwnerStreetAddress, OwnerCityAddress, OwnerStateAddress
FROM PortfolioProject2..NashvilleHousing

--CLEANING Y/N From SoldAsVacant Column

SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM PortfolioProject2..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2 DESC

SELECT SoldAsVacant
, CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	   WHEN SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END
FROM PortfolioProject2..NashvilleHousing

UPDATE NashvilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	   WHEN SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END


WITH RowNumCTE AS(
SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					ParcelID
					) row_num

FROM PortfolioProject2..NashvilleHousing
--ORDER BY ParcelID
)

DELETE
FROM RowNumCTE
WHERE row_num >1
--ORDER BY PropertyAddress



--DELETE Unused Columns

SELECT *
FROM PortfolioProject2..NashvilleHousing

ALTER TABLE PortfolioProject2..NashvilleHousing
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress, SaleDate




