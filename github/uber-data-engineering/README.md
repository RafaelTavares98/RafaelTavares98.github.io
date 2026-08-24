
<!-- PROJECT SHIELDS -->
[![LinkedIn][linkedin-shield]][linkedin-url]



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/viollysa/uber-data-engineering">
    <img src="images/purple.png" alt="Logo" width="80" height="80">
  </a>

<h3 align="center">Data Engineering with Uber</h3>

  <p align="center">
    Personal project to analyze Uber data using various tools and technologies, including Google Cloud Platform storage, Python (via Jupyter Notebook), Compute Instance, Mage Data Pipeline tool, Big Query, and Looker Studio.
    <br />
    <br />
    <a href="https://github.com/viollysa/uber-data-engineering><strong>Explore the docs»</strong></a>
    <a href="https://github.com/viollysa/uber-data-engineering">View Demo</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#understanding-the-data">Understanding the Data</a></li>
        <li><a href="#er-diagram">Createing an ER Diagram with LucidChart</a></li>
        <li><a href="#jupyter-notebook">Writing the Transformation Code in Jupyter Notebook</a></li>
        <li><a href="#google-cloud-platform">Virtual Machines on Google Cloud Platform</a></li>
        <li><a href="#mage-ai">Using Mage.AI's Data Pipeline</a></li>
        <li><a href="#bigquery">SQL with BigQuery</a></li>
        <li><a href="#findings">Findings</a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project
[![Uber Dashboard][product-screenshot]](https://lookerstudio.google.com/s/teJcFnW7XOc)

### This is my first personal project that was documented on GitHub!
Within this project, I was able to explore more on [Google Cloud Platform](https://cloud.google.com/gcp?utm_source=google&utm_medium=cpc&utm_campaign=na-US-all-en-dr-bkws-all-all-trial-e-dr-1605212&utm_content=text-ad-none-any-DEV_c-CRE_665735450627-ADGP_Hybrid+%7C+BKWS+-+EXA+%7C+Txt_Google+Cloud-KWID_43700077223807301-kwd-26415313501&utm_term=KW_google+cloud+platform-ST_google+cloud+platform&gad_source=1&gclid=CjwKCAiAjfyqBhAsEiwA-UdzJP6AN9-rqjYNg3IRoSr-cLrC76RytOvvULCXEfJ5yQVKZe0YA560_RoCKl4QAvD_BwE&gclsrc=aw.ds&hl=en) and introduce myself to [Mage.ai](https://www.mage.ai/).

<!-- UNDERSTANDING THE DATA -->
### Understanding the Data
To start the project, I used an [Uber dataset](https://github.com/viollysa/uber-data-engineering/blob/main/data/uber_data.csv) from 2016 that focused on pickups and dropoffs in New York. I went through the data using Excel and removed the extra attributes that were not going to be used in this project.

<!-- CREATE ER -->
### Creating an ER Diagram with LucidChart
Once I had a good understanding of the dataset, I created a rudimentary entity relationship diagram to understand how the data would be flowing:

![ER Diagram](/images/er-diagram.PNG)

<!-- JUPYTER NOTEBOOK -->
### Writing Transformation Code in Jupyter Notebook
I continued on to creating a [Jupyter Notebook](https://github.com/viollysa/uber-data-engineering/blob/main/uber.ipynb) on my local terminal with the Uber data uploaded. I explored the data and created transformation code that would clean and organize the data into more readable dataframes, making sure to follow the ER diagram's guide. Uber also had [two data dictionaries](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf) available and I created and mapped the values to the correct variables.


<!-- GOOGLE CLOUD PLATFORM -->
![Google Cloud Platform](/images/gcp2.PNG)
### Virtual Machines on Google Cloud Platform
Continuing on, I moved forward to making the raw data available online via Google Cloud Platform.
I created a VM (virtual machine) instance to be able to engineer the data better. I installed Python on the virtual machine and followed Mage.ai's documentation to make the data pipeline available to me using my local host.

<!-- MAGE AI -->
### Using Mage.AI's Data Pipeline
Within the Mage.ai data pipeline, I was able to load the data in using the public URL to the data provided by GCP. I then used the scripts from my Jupyter Notebook to transform the raw data through Mage.ai.
Once everything was loaded and transformed, I used GCP to provide myself with a JSON file containing my private key, so that I could connect Mage.ai to GCP's BigQuery. 

![Flowchart of Code](/images/mage1.PNG)

I changed in the information in the 'config.yaml' file to the appropiate keys and addresses to configure everthing correctly. When my data pipeline from my virtual machine was connected to BigQuery, I created a loadout code to be able to export the transformed data into a new dataset named 'fact_table.' 
![Successful Execution](/images/mage2.PNG)

<!-- BIGQUERY -->
### SQL with BigQuery
All of the data exported out and I was now able to explore my transformed data within BigQuery. The code shows me exploring the new table.

![SQL Scripts](/images/gcp.PNG)

I opened a new SQL script to select specfic variables. I referred back to my ER diagram and joined all of the foreign keys into one table named 'fact_table.' The 'fact_table' would be the last table I created because this one held all of the foreign keys and important variables joined on the primary key of 'vendor_id.' Once created, I used the dataset to create a dashboard via LookerStudio to explore the data and express my findings.

<!-- FINDINGS -->
### Findings
Some of my smaller findings include that in March 2016, the average fare amount was $13.25 and the average distance travelled in an Uber was 3 miles. To see more of my findings, please feel free to explore the [dashboard](https://lookerstudio.google.com/s/teJcFnW7XOc).

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- BUILT WITH -->
### Built With

* [![Python][Python.py]][Python-url]
* [![Jupyter][Jupyter.ipynb]][Jupyter-url]
* [![BigQuery][Bigquery.js]][Bigquery-url]
* [![MageAI][Mage.ai]][Mage-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- CONTACT -->
## Contact

Allysa Tahimik - [LinkedIn](https://www.linkedin.com/in/allysatahimik/) - allytahimik@gmail.com

Project Link: [https://github.com/viollysa/uber-data-engineering](https://github.com/viollysa/uber-data-engineering)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [Pandas](https://pandas.pydata.org/)
* [More Info on Uber Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/allysatahimik
[product-screenshot]: images/dashboard.PNG
[er-diagram]: images.er-diagram.PNG
[Python.py]: https://img.shields.io/badge/Python-000000?style=for-the-badge&logo=python&logoColor=white
[Python-url]: https://www.python.org/
[Jupyter.ipynb]: https://img.shields.io/badge/Jupyter-20232A?style=for-the-badge&logo=jupyter&logoColor=61DAFB
[Jupyter-url]: https://jupyter.org/
[Bigquery.js]: https://img.shields.io/badge/BigQuery-35495E?style=for-the-badge&logo=google&logoColor=4FC08D
[Bigquery-url]: https://cloud.google.com/bigquery?hl=en
[Mage.ai]: https://img.shields.io/badge/Mage.AI-DD0031?style=for-the-badge&logo=&logoColor=white
[Mage-url]: https://www.mage.ai/
