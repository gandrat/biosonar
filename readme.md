# Distribuição Espaço-Temporal de Cetáceos na Bacia de Pelotas

Repositório contendo os scripts de estruturação de banco de dados geoespacial, limpeza de dados e análises visuais para o Trabalho de Conclusão de Curso (TCC) do **Curso Técnico em Geoprocessamento** do **Instituto Federal do Rio Grande do Sul (IFRS)**.

---

## Sobre o Projeto

O avanço das fronteiras exploratórias de petróleo e gás na Bacia de Pelotas exige uma compreensão detalhada da biodiversidade marinha local para mitigar impactos ambientais, especialmente aqueles associados às pesquisas sísmicas e ao tráfego de embarcações. Este projeto integra dados biológicos de monitoramento marinho com ferramentas de Sistemas de Informação Geográfica (SIG) e Bancos de Dados Geográficos para avaliar a ocorrência de cetáceos na região.

### Objetivo Geral
Analisar a distribuição espaço-temporal de cetáceos nos blocos exploratórios de petróleo e gás na Bacia de Pelotas.

### Objetivos Específicos
* Mapear a ocorrência de cetáceos na região;
* Comparar a eficácia e abrangência dos métodos de detecção visual (avistagens) e acústica (Monitoramento Acústico Passivo - PAM);
* Analisar a sazonalidade de ocorrência por espécies;
* Interpretar padrões espaciais das principais espécies registradas na região.

---

## Tecnologias e Ferramentas Utilizadas

* **Linguagem de Programação:** R
  * Manipulação e limpeza de dados: `dplyr`, `janitor`, `readODS`, `forcats`
  * Geoprocessamento e dados espaciais: `sf`
  * Conexão com Banco de Dados: `DBI`, `RPostgres`
  * Visualização de dados: `ggplot2`
* **Banco de Dados Espacial:** PostgreSQL + extensão **PostGIS**
* **SIG Desktop:** QGIS (para integração com os blocos exploratórios da ANP e elaboração dos mapas temáticos)

---

## Estrutura do Banco de Dados (PostGIS)

Os dados brutos provenientes de planilhas `.ods` são higienizados via R, convertidos em feições geométricas de pontos (`SIRGAS 2000 / EPSG:4674`) e armazenados no esquema `public` do PostgreSQL seguindo um modelo relacional:

| Tabela | Tipo | Chave Primária (PK) | Chave Estrangeira (FK) | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| **`species`** | Alfanumérica | `taxon` (`TEXT`) | — | Dicionário taxonômico validado (Ordem, Subordem, Família, Gênero, Espécie e Táxon). |
| **`sightings`** | Espacial (`POINT`) | `id_avist` (`TEXT`) | `taxon` $\rightarrow$ `species(taxon)` | Registros de avistagens visuais com coordenadas geográficas, horários e esforço amostral. |
| **`detections`** | Espacial (`POINT`) | `id_detec` (`TEXT`) | `taxon` $\rightarrow$ `species(taxon)` | Registros de detecções acústicas passivas (PAM) espacializados. |

* As tabelas espaciais possuem índices espaciais **GIST** configurados sobre a coluna geométrica (`geom`) para otimizar consultas espaciais e renderização no QGIS.

---

## Como Reproduzir o Fluxo de Trabalho

### 1. Pré-requisitos
Certifique-se de ter o **R** (versão 4.1+) e um servidor **PostgreSQL/PostGIS** ativo. No console do R, instale os pacotes necessários:

```R
install.packages(c("readODS", "DBI", "RPostgres", "janitor", "sf", "dplyr", "ggplot2", "forcats"))
```

### 2. Etapas de Execução
1. **Importação e Limpeza (`01_import_to_postgis.R`):**
   * Lê as abas de avistagens, detecções e espécies do arquivo `.ods`;
   * Padroniza nomes de colunas (`snake_case`), corrige inconsistências taxonômicas e converte tipos de dados de tempo (`TIME`);
   * Transforma as coordenadas (`lon`, `lat`) em geometrias `POINT` (`EPSG:4674`) e exporta para o PostGIS;
   * Define as restrições de integridade referencial (`PRIMARY KEY` e `FOREIGN KEY` com `ON UPDATE CASCADE`).
2. **Análise Exploratória e Gráficos (`02_exploratory_plots.R`):**
   * Consulta o banco de dados unificando (`UNION ALL`) avistagens visuais e detecções acústicas;
   * Gera gráficos comparativos de ocorrência por Subordem e Família em alta resolução (`300 dpi`) para inclusão no documento final do TCC.

---

## Principais Saídas (Outputs)

* Tabelas espaciais estruturadas no PostGIS prontas para cruzamento espacial (`ST_Intersects`, mapas de Kernel, etc.) com os polígonos dos blocos exploratórios da Bacia de Pelotas;
* Gráficos comparativos (`fig_sightings_vs_detections_family.png`) demonstrando a complementaridade entre o monitoramento visual e o acústico entre diferentes famílias de Odontoceti e Mysticeti.

---

## Autoria

Trabalho desenvolvido no âmbito do **Curso Técnico em Geoprocessamento — IFRS**.