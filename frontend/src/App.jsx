import React, { useState, useEffect } from 'react';
import './App.css'; // Mantenha o arquivo CSS padrão do Vite/React, se houver

function App() {
    const [products, setProducts] = useState([]);
    const [newProductName, setNewProductName] = useState('');
    const [newProductDescription, setNewProductDescription] = useState('');
    const [newProductPrice, setNewProductPrice] = useState('');
    const [editingProduct, setEditingProduct] = useState(null); // Para armazenar o produto sendo editado

    const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/api/products';

    useEffect(() => {
        fetchProducts();
    }, []);

    const fetchProducts = async () => {
        try {
            const response = await fetch(API_URL);
            const data = await response.json();
            setProducts(data);
        } catch (error) {
            console.error('Error fetching products:', error);
        }
    };

    const handleCreateProduct = async (e) => {
        e.preventDefault();
        const productData = {
            name: newProductName,
            description: newProductDescription,
            price: parseFloat(newProductPrice)
        };

        try {
            await fetch(API_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(productData),
            });
            setNewProductName('');
            setNewProductDescription('');
            setNewProductPrice('');
            fetchProducts();
        } catch (error) {
            console.error('Error creating product:', error);
        }
    };

    const handleDeleteProduct = async (id) => {
        try {
            await fetch(`${API_URL}/${id}`, {
                method: 'DELETE',
            });
            fetchProducts();
        } catch (error) {
            console.error('Error deleting product:', error);
        }
    };

    const handleEditClick = (product) => {
        setEditingProduct(product);
        setNewProductName(product.name);
        setNewProductDescription(product.description);
        setNewProductPrice(product.price.toString());
    };

    const handleUpdateProduct = async (e) => {
        e.preventDefault();
        if (!editingProduct) return;

        const productData = {
            name: newProductName,
            description: newProductDescription,
            price: parseFloat(newProductPrice)
        };

        try {
            await fetch(`${API_URL}/${editingProduct.id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(productData),
            });
            setEditingProduct(null);
            setNewProductName('');
            setNewProductDescription('');
            setNewProductPrice('');
            fetchProducts();
        } catch (error) {
            console.error('Error updating product:', error);
        }
    };

    return (
        <div className="App">
            <h1>Gerenciador de Produtos</h1>

            <div className="product-form">
                <h2>{editingProduct ? 'Editar Produto' : 'Adicionar Novo Produto'}</h2>
                <form onSubmit={editingProduct ? handleUpdateProduct : handleCreateProduct}>
                    <input
                        type="text"
                        placeholder="Nome do Produto"
                        value={newProductName}
                        onChange={(e) => setNewProductName(e.target.value)}
                        required
                    />
                    <input
                        type="text"
                        placeholder="Descrição do Produto"
                        value={newProductDescription}
                        onChange={(e) => setNewProductDescription(e.target.value)}
                        required
                    />
                    <input
                        type="number"
                        step="0.01"
                        placeholder="Preço"
                        value={newProductPrice}
                        onChange={(e) => setNewProductPrice(e.target.value)}
                        required
                    />
                    <button type="submit">
                        {editingProduct ? 'Atualizar Produto' : 'Adicionar Produto'}
                    </button>
                    {editingProduct && (
                        <button type="button" onClick={() => {
                            setEditingProduct(null);
                            setNewProductName('');
                            setNewProductDescription('');
                            setNewProductPrice('');
                        }}>Cancelar Edição</button>
                    )}
                </form>
            </div>

            <div className="product-list">
                <h2>Produtos Existentes</h2>
                {products.length === 0 ? (
                    <p>Nenhum produto cadastrado.</p>
                ) : (
                    <ul>
                        {products.map((product) => (
                            <li key={product.id}>
                                <strong>{product.name}</strong> - {product.description} (R$ {product.price.toFixed(2)})
                                <button onClick={() => handleEditClick(product)}>Editar</button>
                                <button onClick={() => handleDeleteProduct(product.id)}>Excluir</button>
                            </li>
                        ))}
                    </ul>
                )}
            </div>
        </div>
    );
}

export default App;