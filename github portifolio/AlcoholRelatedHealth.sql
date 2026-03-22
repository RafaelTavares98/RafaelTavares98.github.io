SELECT *
FROM PortfolioProject3..['death_risk_factors']

SELECT *
FROM PortfolioProject3..['life-expectancy']

SELECT *
FROM PortfolioProject3..['share_never_drink']

SELECT *
FROM PortfolioProject3..['share_one_year_not_drink']

SELECT *
FROM PortfolioProject3..['total-alcohol-consumption']

SELECT * 
FROM PortfolioProject3..['life-expectancy']
ORDER BY [Life_expectancy_at_birth)] DESC




--Countries with the Highest Life Expectancy with related % Population of Lifetime Alcohol Abstainers
SELECT TOP 10 life.Entity, life.year, life.[Life_expectancy_at_birth)], never.[Indicator:Alcohol, abstainers lifetime (%) - Sex:Both sexes]
FROM PortfolioProject3..['life-expectancy'] life
FULL OUTER JOIN PortfolioProject3..['share_never_drink'] never
	ON life.Entity = never.Entity
	and life.Year = never.Year
WHERE never.[Indicator:Alcohol, abstainers lifetime (%) - Sex:Both sexes] is NOT NULL
ORDER BY Life.[Life_expectancy_at_birth)] DESC


--Countries with the Lowest Life Expectancy with related % Population of Lifetime Alcohol Abstainers
SELECT TOP 10 life.Entity, life.year, life.[Life_expectancy_at_birth)], never.[Indicator:Alcohol, abstainers lifetime (%) - Sex:Both sexes]
FROM PortfolioProject3..['life-expectancy'] life
FULL OUTER JOIN PortfolioProject3..['share_never_drink'] never
	ON life.Entity = never.Entity
	and life.Year = never.Year
WHERE never.[Indicator:Alcohol, abstainers lifetime (%) - Sex:Both sexes] is NOT NULL
ORDER BY Life.[Life_expectancy_at_birth)] 

--Countries with the Highest Life Expectancy with related % Population of One Year Alcohol Abstainers
SELECT TOP 10 life.Entity, life.year, life.[Life_expectancy_at_birth)], one.[Indicator:Alcohol, abstainers past 12 months (%) - Sex:Both sexe]
FROM PortfolioProject3..['life-expectancy'] life
FULL OUTER JOIN PortfolioProject3..['share_never_drink'] never
	ON life.Entity = never.Entity
	and life.Year = never.Year
FULL OUTER JOIN PortfolioProject3..['share_one_year_not_drink'] one
	ON life.Entity = one.Entity
	and life.year = one.year
WHERE one.[Indicator:Alcohol, abstainers past 12 months (%) - Sex:Both sexe] is NOT NULL
ORDER BY Life.[Life_expectancy_at_birth)] DESC

--Countries with the Lowest Life Expectancy with related % Population of One Year Alcohol Abstainers
SELECT TOP 10 life.Entity, life.year, life.[Life_expectancy_at_birth)], one.[Indicator:Alcohol, abstainers past 12 months (%) - Sex:Both sexe]
FROM PortfolioProject3..['life-expectancy'] life
FULL OUTER JOIN PortfolioProject3..['share_never_drink'] never
	ON life.Entity = never.Entity
	and life.Year = never.Year
FULL OUTER JOIN PortfolioProject3..['share_one_year_not_drink'] one
	ON life.Entity = one.Entity
	and life.year = one.year
WHERE one.[Indicator:Alcohol, abstainers past 12 months (%) - Sex:Both sexe] is NOT NULL
ORDER BY Life.[Life_expectancy_at_birth)]


ALTER TABLE PortfolioProject3..['death_risk_factors']
ADD SumDeaths int

UPDATE PortfolioProject3..['death_risk_factors']
SET SumDeaths = (Deaths_High_Blood_Pressure
										+ Deaths_High_Sodium 
										+ Deaths_Low_Whole_Grains 
										+ Deaths_Air_Pollution 
										+ Deaths_Alcohol_Use 
										+ Deaths_Ambient_Particulate_Matter_Pollution 
										+ Deaths_Child_Stunting 
										+ Deaths_Child_Wasting 
										+ Deaths_Drug_Use 
										+ Deaths_High_Body_Mass_Index 
										+ Deaths_High_Fasting_Plasma_Glucose 
										+ Deaths_High_Sodium 
										+ Deaths_Household_Air_Pollution 
										+ Deaths_Iron_Deficiency 
										+ Deaths_Low_Birth_Weight 
										+ Deaths_Low_Bone_Mineral_Density 
										+ Deaths_Low_Fruit_Consumption 
										+ Deaths_Low_Physical_Actvitiy 
										+ [Deaths_Low_Seed/Nut_Consumption] 
										+ Deaths_Low_Vegatable_Consumption 
										+ Deaths_Low_Whole_Grains 
										+ Deaths_No_Hand_Washing_Facilities 
										+ Deaths_NonExclusive_Breastfeeding 
										+ Deaths_Second_Hand_Smoke 
										+ Deaths_Smoking 
										+ Deaths_Unsafe_Sanitation 
										+ Deaths_Unsafe_Sex 
										+ Deaths_Unsafe_Water 
										+ Deaths_Vitamin_A_Deficiency)


--Percentage Share of Alcohol Deaths Compared to Total
SELECT Entity, year, Deaths_Alcohol_Use, SumDeaths, (Deaths_Alcohol_Use/ Sumdeaths) *100 as Alcohol_Use_Share
FROM PortfolioProject3..['death_risk_factors']


--Correlating Alcohol Consumption with the Share of Alcohol related deaths
SELECT TOP 10 risk.Entity, risk.Year, risk.Deaths_Alcohol_Use, risk.SumDeaths, (risk.Deaths_Alcohol_Use/ risk.SumDeaths) *100 as Alcohol_Use_Share, total.[Total alcohol consumption per capita (liters of pure alcohol, pr]
FROM PortfolioProject3..['death_risk_factors'] risk
FULL OUTER JOIN PortfolioProject3..['total-alcohol-consumption'] total
	ON risk.Entity = total.Entity 
	and risk.Year = total.year
WHERE total.code is NOT NULL
ORDER BY 5 DESC

SELECT TOP 10 risk.Entity, risk.Year, risk.Deaths_Alcohol_Use, risk.SumDeaths, (risk.Deaths_Alcohol_Use/ risk.SumDeaths) *100 as Alcohol_Use_Share, total.[Total alcohol consumption per capita (liters of pure alcohol, pr]
FROM PortfolioProject3..['death_risk_factors'] risk
FULL OUTER JOIN PortfolioProject3..['total-alcohol-consumption'] total
	ON risk.Entity = total.Entity 
	and risk.Year = total.year
WHERE risk.Year is NOT NULL
and total.[Total alcohol consumption per capita (liters of pure alcohol, pr] is NOT NULL
ORDER BY 5 


SELECT *
FROM PortfolioProject3..['total-alcohol-consumption']