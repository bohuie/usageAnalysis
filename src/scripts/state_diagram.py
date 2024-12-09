import pandas as pd
import networkx as nx
import matplotlib.pyplot as plt

file_path = input("Please enter the path to your CSV file: ")

data = pd.read_csv(file_path, index_col=0)

transition_matrix = data.values

states = list(data.index)
transition_dict = {states[i]: {states[j]: transition_matrix[i, j] for j in range(len(states))} for i in range(len(states))}

G = nx.DiGraph()

for state, transitions in transition_dict.items():
    G.add_node(state, color='lightblue', size=8) 
    for next_state, probability in transitions.items():
        if probability > 0: 
            G.add_edge(state, next_state, weight=probability, label=f"{probability:.2f}")

pos = nx.spring_layout(G, k=1, seed=42)  

plt.figure(figsize=(12, 12)) 

nx.draw_networkx_nodes(G, pos, node_size=1500, node_color="lightblue")  

nx.draw_networkx_edges(
    G, pos, arrows=True, arrowstyle="->", arrowsize=30, edge_color="black", 
    connectionstyle="arc3,rad=0", width=2 
)

nx.draw_networkx_labels(G, pos, font_size=10)
edge_labels = nx.get_edge_attributes(G, 'label')
nx.draw_networkx_edge_labels(G, pos, edge_labels=edge_labels, font_size=8)

plt.axis("off")
plt.show()

