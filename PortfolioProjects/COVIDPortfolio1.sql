SELECT * 
FROM PortfolioProject1..['Covid-Deaths']
--WHERE location = 'Low income' or location = 'World'
WHERE continent IS NOT NULL
ORDER BY 3,4


SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject1..['Covid-Deaths']
WHERE continent IS NOT NULL
ORDER BY 1,2

--Looking at Total Cases vs. Total Deaths
--Shows Likelyhood of Dying if Contracted with Covid-19 in a Country


SELECT Location, date, total_cases,total_deaths, 
(CONVERT(float, total_deaths) / NULLIF(CONVERT(float, total_cases), 0)) * 100 AS DeathPercentage
FROM PortfolioProject1..['Covid-Deaths']
--WHERE location Like '%states'
WHERE continent IS NOT NULL
ORDER BY 1,2

--Looking at Total Cases vs Population

SELECT Location, date, population, total_cases, 
(CONVERT(int, total_cases) / population) * 100 AS CasePopulationRate
FROM PortfolioProject1..['Covid-Deaths']
--WHERE location Like '%states'
WHERE continent IS NOT NULL
ORDER BY 1,2

--Population Vs, Infection Rate, Highest Infection Rate Compared to Population

SELECT location, population, MAX(CONVERT(int, total_cases)) as HighestInfectionCount, MAX((CONVERT(int, total_cases) / population)) * 100 AS PercentPopulationInfected
FROM PortfolioProject1..['Covid-Deaths']
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC


--Countries with Highest Death Count per Population

SELECT location, MAX(CONVERT(int, total_deaths)) as TotalDeathCount
FROM PortfolioProject1..['Covid-Deaths']
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC
    

SELECT continent, MAX(CONVERT(int, total_deaths)) as TotalDeathCount
FROM PortfolioProject1..['Covid-Deaths']
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC


--GLOBAL NUMBERS

--TOTAL DEATHS
SELECT SUM(new_cases) AS TotalCases, SUM(new_deaths) AS TotalDeaths, SUM(new_deaths)/NULLIF(SUM(new_cases), 0)* 100 AS PercentageDeath
FROM PortfolioProject1..['Covid-Deaths']
--WHERE location Like '%states'
WHERE continent IS NOT NULL
--GROUP BY date
ORDER BY 1,2

--NEW CASES AND DEATHS PER DAY
SELECT date, SUM(new_cases) AS TotalCases, SUM(new_deaths)as TotalCases, SUM(new_deaths)/NULLIF(SUM(new_cases), 0)* 100 AS PercentageDeath
FROM PortfolioProject1..['Covid-Deaths']
--WHERE location Like '%states'
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1,2


--Total Population vs Vaccinations

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations_smoothed, 
(SUM(CONVERT(bigint,vac.new_vaccinations_smoothed)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date)) AS RollingPeopleVaccinated,
(population*100)
FROM PortfolioProject1..['Covid-Deaths'] dea
JOIN PortfolioProject1..['Covid-Vaccinations'] vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3

--CTE TABLE

WITH PopvsVac(Continent, Locations, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS 
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations_smoothed, 
(SUM(CONVERT(bigint,vac.new_vaccinations_smoothed)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date)) AS RollingPeopleVaccinated
FROM PortfolioProject1..['Covid-Deaths'] dea
JOIN PortfolioProject1..['Covid-Vaccinations'] vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent IS NOT NULL
)
SELECT *, (RollingPeopleVaccinated/Population)* 100 AS Population_Vaccinated
FROM PopvsVac

--TEMP Table

DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
RollingPeopleVaccinated numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations_smoothed, 
(SUM(CONVERT(bigint,vac.new_vaccinations_smoothed)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date)) AS RollingPeopleVaccinated
FROM PortfolioProject1..['Covid-Deaths'] dea
JOIN PortfolioProject1..['Covid-Vaccinations'] vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent IS NOT NULL

SELECT *, (RollingPeopleVaccinated/Population)* 100 AS Population_Vaccinated
FROM #PercentPopulationVaccinated


CREATE VIEW Continent_DeathCount AS
SELECT continent, MAX(CONVERT(int, total_deaths)) as TotalDeathCount
FROM PortfolioProject1..['Covid-Deaths']
WHERE continent IS NOT NULL
GROUP BY continent
--ORDER BY TotalDeathCount DESC