import argparse, os
import yaml
from typing import List
from langchain_community.document_loaders import WebBaseLoader,  BSHTMLLoader
from langchain_chroma  import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_openai import OpenAIEmbeddings
import chromadb
from pathlib import Path
from dotenv import load_dotenv

DOMAIN_VS_PATH="./agent_domain_store"
DEFAULT_K = 4 
load_dotenv(dotenv_path="../.env")
embeddings = OpenAIEmbeddings()

parser = argparse.ArgumentParser(
    prog=os.path.basename(__file__), 
    description="Tool to load the yaml file and parse the URLs"
)
parser.add_argument("-c", "--config", required= True, help= "The configuration file to run the preparation")
parser.add_argument("-d", "--domain", required= True, help= "The domain name to create or update")
parser.add_argument("-q", "--query", required= False, help="query the corpus without LLM")

def load_config(filename: str) -> dict:
    with open(filename, "r", encoding="utf-8") as f:
        app_config = yaml.load(f, Loader=yaml.FullLoader)
        print(app_config)
    return app_config


def get_vector_store(domain: str, local: bool = True):
    """_summary_

    Args:
        domain (str): domain name which is also collection name
        local (bool, optional): local or remote vector store. Defaults to True.

    Returns:
        vector store
    """
    if local:
        vs= Chroma(
            collection_name=domain,
            embedding_function=embeddings,
            persist_directory= DOMAIN_VS_PATH,  
        )
    else:
        client = chromadb.PersistentClient()
        client.get_or_create_collection(name=domain, metadata={"hnsw:space": "cosine"})
        vs= Chroma(client=client, 
                   collection_name=domain, 
                   embedding_function=embeddings)
    return vs

def load_urls_content_save_splits(domain: str, urls: str, type: str):
    if type == "html":
        docs = [BSHTMLLoader(url).load() for url in urls]
    else:
        docs = [WebBaseLoader(url).load() for url in urls]
    doc_list= [item for sublist in docs for item in sublist]
    text_splitter = RecursiveCharacterTextSplitter.from_tiktoken_encoder(chunk_size=200, 
                                                                         chunk_overlap=0, 
                                                                         add_start_index=True)
    doc_splits = text_splitter.split_documents(doc_list)
    print(f" The number of document splits: {len(doc_splits)}")
    ids= [ str(id) for id in range(len(doc_splits)) ]
    id = 0
    for chunk in doc_splits:
        print(chunk.metadata["title"])
        with open("./raw_" + domain + "/" + str(id) + ".yaml", "w") as f:
            f.write(f"id: {id}\n\t{chunk}")
    
def build_content_for_domain(domain: str, config: dict):
    print("---- BUILD CORPUS CONTENT -----")
    load_urls_content_save_splits(domain, config[domain]["urls"], config[domain]["type"])


def save_to_vector_store(domain: str, doc_splits):
    vs = get_vector_store(domain, config["chroma"] == "local")
    vs.add_documents(documents=doc_splits)

def query_corpus(domain: str, query: str, config: dict):
    vs=get_vector_store(domain,config["chroma"] == "local")
    results = vs.similarity_search(query, k=3)
    for res in results:
        print(f"@@@@ {res.page_content} [{res.metadata}]")

if __name__ == "__main__":
    args = parser.parse_args()
    config=load_config(args.config)
    if args.query:
        query_corpus(args.domain, args.query, config)
    else:
        build_content_for_domain(args.domain,config)