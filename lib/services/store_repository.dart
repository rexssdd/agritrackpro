import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entities.dart';

class CartLine { final Product product; int quantity; CartLine(this.product,[this.quantity=1]); }

class StoreRepository {
  final db=FirebaseFirestore.instance;
  final auth=FirebaseAuth.instance;
  String get uid=>auth.currentUser!.uid;
  CollectionReference<Map<String,dynamic>> get products=>db.collection('products');
  CollectionReference<Map<String,dynamic>> get sales=>db.collection('sales');
  CollectionReference<Map<String,dynamic>> get expenses=>db.collection('expenses');
  Stream<List<Product>> watchProducts()=>products.orderBy('name').snapshots().map((s)=>s.docs.map(Product.fromDoc).toList());
  Stream<List<Sale>> watchSales()=>sales.orderBy('createdAt',descending:true).limit(500).snapshots().map((s)=>s.docs.map((d)=>Sale(d.id,d.data())).toList());
  Stream<List<Expense>> watchExpenses()=>expenses.orderBy('createdAt',descending:true).limit(500).snapshots().map((s)=>s.docs.map((d)=>Expense(d.id,d.data())).toList());
  Stream<DocumentSnapshot<Map<String,dynamic>>> watchProfile()=>db.collection('users').doc(uid).snapshots();
  Future<void> saveProduct(Product p) async {
    if(p.name.trim().isEmpty||p.price<0||p.cost<0||p.stock<0||p.reorderLevel<0) throw Exception('Check product details');
    if(p.id.isEmpty){await products.add(p.toMap());}else{await products.doc(p.id).update({...p.toMap()}..remove('stock'));}
  }
  Future<void> adjustStock(Product p,int delta,String reason) async {
    if(delta==0||reason.trim().isEmpty) throw Exception('Enter an adjustment and reason');
    final ref=products.doc(p.id);final log=db.collection('stock_movements').doc();
    await db.runTransaction((tx)async{
      final doc=await tx.get(ref); if(!doc.exists) throw Exception('Product not found');
      final current=n(doc.data()?['stock']).toInt();if(current+delta<0)throw Exception('Not enough stock');
      tx.update(ref,{'stock':current+delta,'updatedAt':FieldValue.serverTimestamp()});
      tx.set(log,{'productId':p.id,'productName':p.name,'delta':delta,'reason':reason.trim(),'userId':uid,'createdAt':FieldValue.serverTimestamp()});
    });
  }
  Future<String> checkout(List<CartLine> cart,{required String method,required double amountPaid,required String customer}) async {
    if(cart.isEmpty)throw Exception('Cart is empty');
    if(!['Cash','GCash','Bank transfer'].contains(method))throw Exception('Invalid payment method');
    final refs=cart.map((l)=>products.doc(l.product.id)).toList();
    final saleRef=sales.doc();
    await db.runTransaction((tx)async{
      // All reads occur before writes; prices and costs are taken from current server data.
      final docs=<DocumentSnapshot<Map<String,dynamic>>>[];
      for(final ref in refs){docs.add(await tx.get(ref));}
      double total=0,cost=0;final items=<Map<String,dynamic>>[];
      for(var i=0;i<cart.length;i++){
        final d=docs[i];final line=cart[i];if(!d.exists)throw Exception('Product was removed');
        final m=d.data()!;final stock=n(m['stock']).toInt();
        if(m['active']==false||line.quantity<=0||stock<line.quantity)throw Exception('Insufficient stock: ${m['name']}');
        final price=n(m['price']).toDouble(),unitCost=n(m['cost']).toDouble();
        total+=price*line.quantity;cost+=unitCost*line.quantity;
        items.add({'productId':d.id,'name':m['name'],'quantity':line.quantity,'unit':m['unit'],'price':price,'unitCost':unitCost,'subtotal':price*line.quantity});
      }
      if(amountPaid<total)throw Exception('Payment is less than total');
      for(var i=0;i<cart.length;i++){
        tx.update(refs[i],{'stock':n(docs[i].data()!['stock']).toInt()-cart[i].quantity,'updatedAt':FieldValue.serverTimestamp()});
      }
      tx.set(saleRef,{'items':items,'total':total,'cost':cost,'amountPaid':amountPaid,'change':amountPaid-total,'method':method,'customer':customer.trim(),'cashierId':uid,'createdAt':FieldValue.serverTimestamp()});
    });
    return saleRef.id;
  }
  Future<void> addExpense(String description,String category,double amount) async {
    if(description.trim().isEmpty||amount<=0)throw Exception('Enter valid expense details');
    await expenses.add({'description':description.trim(),'category':category,'amount':amount,'createdBy':uid,'createdAt':FieldValue.serverTimestamp()});
  }
}
