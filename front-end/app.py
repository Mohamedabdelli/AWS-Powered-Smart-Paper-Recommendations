import streamlit as st
import requests
import json
import os

base_url = os.environ['base_url']

# Configuration de la page
st.set_page_config(page_title="Paper Recommendation", page_icon=":book:", layout="wide")

# Titre
st.title("Paper Recommendation System")

# Créer deux colonnes pour l'entrée des données
col1, col2 = st.columns(2)

# Colonne pour entrer le thème
with col1:
    st.header("Register Research Theme")
    theme_input = st.text_input("Enter the research theme:")

    if st.button("Register Theme"):
        if theme_input:
            register_payload = json.dumps({
                "query": theme_input
            })
            headers = {
                'Content-Type': 'application/json'
            }

            register_response = requests.request(
                "POST",
                f"{base_url}/register",
                headers=headers,
                data=register_payload
            )

            if register_response.status_code == 200:
                st.success("Theme registered successfully!")
            else:
                st.error("Failed to register theme.")
        else:
            st.error("Please enter a research theme.")

# Colonne pour entrer la requête de recherche
with col2:
    st.header("Search for Relevant Papers")
    query_input = st.text_input("Enter your query:")

    if st.button("Get Papers"):
        if query_input:
            search_payload = json.dumps({
                "query": query_input
            })
            headers = {
                'Content-Type': 'application/json'
            }

            search_response = requests.request(
                "POST",
                f"{base_url}/recommend",
                headers=headers,
                data=search_payload
            )

            if search_response.status_code == 200:
                result_data = search_response.json()
                answer = result_data.get('answer', 'No answer provided.')
                profiles = result_data.get('profils', [])

                # Affichage de la réponse
                st.write("### Answer")
                st.write(answer)

                # Affichage des articles
                if profiles:
                    for profile in profiles:
                        st.markdown(
                            f"""
                            <div style="border: 2px solid #4CAF50; border-radius: 15px; padding: 20px; background-color: #f9f9f9; margin-bottom: 20px;">
                                <h3 style="color: #333;">{profile.get('title', 'No Title')}</h3>
                                <p><strong>Published:</strong> {profile.get('published', 'No Date')}</p>
                                <p><strong>Authors:</strong> {', '.join(profile.get('authors', []))}</p>
                                <p><strong>Abstract:</strong> <a href="{profile.get('url_abs', '#')}" target="_blank">View Abstract</a></p>
                                <p><strong>PDF:</strong> <a href="{profile.get('url_pdf', '#')}" target="_blank">Download PDF</a></p>
                            </div>
                            """,
                            unsafe_allow_html=True
                        )
                else:
                    st.write("No papers found.")

            else:
                st.error("Failed to retrieve papers.")
        else:
            st.error("Please enter a query.")
